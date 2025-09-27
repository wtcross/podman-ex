defmodule Podman.Client do
  @moduledoc """
  Thin wrapper around [`Req`](https://hexdocs.pm/req/readme.html) tailored for the Podman API.

  The client keeps a pre-configured `Req.Request` struct with default headers,
  base URL, and connection options so that higher level modules can focus on
  resource-specific concerns. Paths passed to the request helpers are appended
  to the configured base URL.
  """

  alias Podman.Error

  @default_base_url "http://localhost:8080/v5.0.0/"

  @type connection_info :: %{optional(atom()) => term()}

  @enforce_keys [:request, :base_url, :connection]
  defstruct [:request, :base_url, :connection]

  @typedoc "Runtime configuration for performing Podman requests."
  @type t :: %__MODULE__{
          request: Req.Request.t(),
          base_url: String.t(),
          connection: connection_info()
        }

  @typedoc "Options accepted by `new/1`."
  @type option ::
          {:base_url, String.t()}
          | {:headers, keyword() | %{optional(String.t()) => String.t()}}
          | {:user_agent, String.t()}
          | {:auth, Req.auth()}
          | {:finch, Finch.name() | {Finch, keyword()}}
          | {:request_options, keyword()}
          | {:ssh_runner,
             (connection_info() ->
                {:ok, %{unix_socket: String.t(), cleanup: (-> any())}} | {:error, term()})}
          | {:identity, String.t()}

  @spec new([option()]) :: t()
  def new(opts \\ []) do
    ssh_runner = Keyword.get(opts, :ssh_runner, &default_ssh_runner/1)

    {normalized_base_url, connection_opts, connection_info} =
      opts
      |> Keyword.get(:base_url, default_base_url())
      |> normalize_connection(ssh_runner, opts)

    finch = Keyword.get(opts, :finch, Podman.Finch)
    user_agent = Keyword.get(opts, :user_agent, default_user_agent())

    headers =
      opts
      |> Keyword.get(:headers, [])
      |> Enum.into(%{})
      |> Map.put_new("user-agent", user_agent)
      |> Map.put_new("accept", "application/json")
      |> Map.to_list()

    base_req_options =
      [
        base_url: normalized_base_url,
        finch: finch,
        headers: headers
      ]
      |> maybe_put(:auth, Keyword.get(opts, :auth))
      |> maybe_put(:unix_socket, connection_opts[:unix_socket])
      |> maybe_put(:connect_options, connection_opts[:connect_options])

    req_options =
      Keyword.merge(
        base_req_options,
        Keyword.get(opts, :request_options, []),
        fn
          :connect_options, v1, v2 -> Keyword.merge(List.wrap(v1), List.wrap(v2))
          :headers, v1, v2 -> Keyword.merge(List.wrap(v1), List.wrap(v2))
          _key, _v1, v2 -> v2
        end
      )

    %__MODULE__{
      request: Req.new(req_options),
      base_url: normalized_base_url,
      connection: connection_info
    }
  end

  @doc """
  Build a client based on Podman/Docker style environment variables.

  Recognised variables:

    * `CONTAINER_HOST` / `DOCKER_HOST` – connection string
    * `CONTAINER_TLS_VERIFY` / `DOCKER_TLS_VERIFY` – if truthy, enable TLS verification
    * `CONTAINER_CERT_PATH` / `DOCKER_CERT_PATH` – directory containing `ca.pem`, `cert.pem`, and `key.pem`

  The `:env` option allows passing a custom environment map for testing.
  """
  @spec from_env(keyword()) :: t()
  def from_env(opts \\ []) do
    env =
      opts
      |> Keyword.get(:env)
      |> normalize_env()

    base_url =
      env["CONTAINER_HOST"] ||
        env["DOCKER_HOST"] ||
        Keyword.get(opts, :base_url)

    tls_verify? = truthy?(env["CONTAINER_TLS_VERIFY"] || env["DOCKER_TLS_VERIFY"])
    cert_path = env["CONTAINER_CERT_PATH"] || env["DOCKER_CERT_PATH"]

    connect_options =
      []
      |> maybe_put_verify(tls_verify?)
      |> maybe_put_certs(cert_path)

    request_options =
      if connect_options == [] do
        Keyword.get(opts, :request_options, [])
      else
        Keyword.update(
          Keyword.get(opts, :request_options, []),
          :connect_options,
          connect_options,
          fn existing -> Keyword.merge(existing, connect_options) end
        )
      end

    opts
    |> Keyword.delete(:env)
    |> maybe_put(:base_url, base_url)
    |> Keyword.put(:request_options, request_options)
    |> new()
  end

  @doc """
  Executes an HTTP request using the configured client.

  Accepted options mirror `Req.request/2`. By default the decoded response body
  is returned (`{:ok, term()}`) on success. Pass `response: :full` to receive the
  full `Req.Response` struct or `response: (response -> term)` to transform the
  successful response.
  """
  @spec request(t(), atom(), String.t() | [String.Chars.t()], keyword()) ::
          {:ok, term()} | {:error, Error.t()}
  def request(%__MODULE__{} = client, method, path, opts \\ []) when is_atom(method) do
    normalized_path = normalize_path(path)
    response_mode = Keyword.get(opts, :response, :body)

    registry_auth = Keyword.get(opts, :registry_auth)

    sanitized_opts =
      opts
      |> Keyword.delete(:response)
      |> Keyword.delete(:registry_auth)
      |> apply_registry_auth(registry_auth)

    request_opts =
      sanitized_opts
      |> Keyword.put(:method, method)
      |> Keyword.put(:url, normalized_path)

    request_context = [
      method: method,
      url: client.base_url <> normalized_path,
      params: Keyword.get(request_opts, :params),
      headers: Keyword.get(request_opts, :headers)
    ]

    case Req.request(client.request, request_opts) do
      {:ok, %Req.Response{} = response} ->
        handle_response(response, response_mode, request_context)

      {:error, %Req.TransportError{} = transport} ->
        {:error, Error.transport_error(transport.reason, request_context)}

      {:error, reason} ->
        {:error, Error.transport_error(reason, request_context)}
    end
  end

  @doc """
  Same as `request/4` but raises `Podman.Error` on error.
  """
  @spec request!(t(), atom(), String.t() | [String.Chars.t()], keyword()) :: term()
  def request!(%__MODULE__{} = client, method, path, opts \\ []) do
    case request(client, method, path, opts) do
      {:ok, value} -> value
      {:error, error} -> raise error
    end
  end

  @doc "Simple helper for GET requests."
  @spec get(t(), String.t() | [String.Chars.t()], keyword()) ::
          {:ok, term()} | {:error, Error.t()}
  def get(client, path, opts \\ []), do: request(client, :get, path, opts)

  @doc "Simple helper for POST requests."
  @spec post(t(), String.t() | [String.Chars.t()], keyword()) ::
          {:ok, term()} | {:error, Error.t()}
  def post(client, path, opts \\ []), do: request(client, :post, path, opts)

  @doc "Simple helper for DELETE requests."
  @spec delete(t(), String.t() | [String.Chars.t()], keyword()) ::
          {:ok, term()} | {:error, Error.t()}
  def delete(client, path, opts \\ []), do: request(client, :delete, path, opts)

  @doc """
  Builds a query map based on a specification list.

  Each specification entry is a `{opt_key, query_key}` tuple or
  `{opt_key, query_key, transformer}` tuple where `transformer` is a unary
  function applied to the extracted option.
  """
  @spec encode_query(keyword(), list()) :: map()
  def encode_query(opts, spec) when is_list(opts) and is_list(spec) do
    Enum.reduce(spec, %{}, fn
      {opt_key, query_key}, acc ->
        maybe_put_query(acc, opts, opt_key, query_key, fn value -> value end)

      {opt_key, query_key, transformer}, acc when is_function(transformer, 1) ->
        maybe_put_query(acc, opts, opt_key, query_key, transformer)
    end)
  end

  @doc """
  Encodes a Podman filter map into the JSON string expected by the API.
  """
  @spec encode_filters(map() | list() | String.t()) :: String.t()
  def encode_filters(filters) when is_binary(filters), do: filters
  def encode_filters(filters) when is_list(filters), do: Jason.encode!(filters)
  def encode_filters(%{} = filters), do: Jason.encode!(filters)

  @doc """
  Closes resources associated with the client (for example SSH tunnels).
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{connection: connection}) do
    cleanup_connection(connection)
    :ok
  end

  @doc false
  @spec default_base_url() :: String.t()
  def default_base_url do
    System.get_env("PODMAN_URL") || @default_base_url
  end

  defp handle_response(%Req.Response{status: status} = response, mode, ctx)
       when status in 200..299 do
    {:ok, map_success(response, mode)}
  rescue
    exception -> {:error, Error.transport_error(exception, ctx)}
  end

  defp handle_response(%Req.Response{} = response, _mode, ctx) do
    {:error, Error.http_error(response, ctx)}
  end

  defp map_success(response, :body) when response.status in [204, 205], do: :ok
  defp map_success(response, :body), do: response.body
  defp map_success(response, :full), do: response
  defp map_success(response, fun) when is_function(fun, 1), do: fun.(response)

  defp ensure_trailing_slash(url) do
    value = to_string(url)

    cond do
      value == "" -> @default_base_url
      String.ends_with?(value, "/") -> value
      true -> value <> "/"
    end
  end

  defp normalize_path(path) when is_binary(path) do
    path
    |> String.trim_leading("/")
  end

  defp normalize_path(path) when is_list(path) do
    path
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
    |> normalize_path()
  end

  defp maybe_put(keyword_list, _key, nil), do: keyword_list
  defp maybe_put(keyword_list, key, value), do: Keyword.put(keyword_list, key, value)

  defp maybe_put_query(acc, opts, opt_key, query_key, mapper) do
    case Keyword.fetch(opts, opt_key) do
      {:ok, value} when value not in [nil, ""] -> Map.put(acc, query_key, mapper.(value))
      _ -> acc
    end
  end

  defp apply_registry_auth(opts, nil), do: opts

  defp apply_registry_auth(opts, auth) do
    header_value = encode_registry_auth(auth)

    headers =
      opts
      |> Keyword.get(:headers, [])
      |> List.wrap()
      |> Enum.reject(fn {name, _} ->
        String.downcase(to_string(name)) == "x-registry-auth"
      end)
      |> List.insert_at(0, {"X-Registry-Auth", header_value})

    opts
    |> Keyword.delete(:headers)
    |> Keyword.put(:headers, headers)
  end

  defp encode_registry_auth(auth) when is_binary(auth), do: auth

  defp encode_registry_auth(auth) when is_list(auth) do
    if Keyword.keyword?(auth) do
      auth
      |> Enum.into(%{})
      |> encode_registry_auth()
    else
      auth |> Enum.map(&to_string/1) |> Enum.join() |> encode_registry_auth()
    end
  end

  defp encode_registry_auth(%{} = auth) do
    auth
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp normalize_connection(nil, ssh_runner, opts) do
    normalize_connection(@default_base_url, ssh_runner, opts)
  end

  defp normalize_connection(base_url, ssh_runner, opts) when is_binary(base_url) do
    uri = URI.parse(base_url)
    scheme = uri.scheme || "http"

    cond do
      scheme in ["http", "https"] ->
        info = %{type: :http, original: base_url}
        {ensure_trailing_slash(URI.to_string(uri)), %{}, info}

      scheme == "tcp" ->
        http_uri = Map.put(uri, :scheme, "http")
        http_base = ensure_trailing_slash(URI.to_string(http_uri))
        {http_base, %{}, %{type: :tcp, original: base_url}}

      scheme in ["unix", "http+unix"] ->
        normalize_unix_connection(uri, base_url)

      scheme in ["ssh", "http+ssh"] ->
        normalize_ssh_connection(uri, opts, ssh_runner, base_url)

      true ->
        raise ArgumentError,
              "Unsupported base_url scheme #{inspect(scheme)}. Expected http, https, tcp, unix/http+unix, ssh/http+ssh"
    end
  end

  defp normalize_unix_connection(uri, original) do
    {socket_path, base_path} = extract_socket_and_path(uri)
    http_base = ensure_trailing_slash("http://d" <> base_path)

    connection = %{
      type: :unix,
      socket_path: socket_path,
      base_path: base_path,
      original: original
    }

    {http_base, %{unix_socket: socket_path}, connection}
  end

  defp normalize_ssh_connection(uri, opts, ssh_runner, original) do
    user = uri.userinfo
    host = uri.host || raise ArgumentError, "http+ssh base_url requires a host"
    port = uri.port || 22
    query = uri.query |> decode_query()

    {remote_socket, base_path} = extract_ssh_socket_and_path(uri)

    secure? = truthy?(Map.get(query, "secure"))
    scheme = if secure?, do: "https", else: "http"
    identity = Keyword.get(opts, :identity)

    info = %{
      type: :ssh,
      user: user,
      host: host,
      port: port,
      remote_socket: remote_socket,
      base_path: base_path,
      secure?: secure?,
      identity: identity,
      original: original
    }

    case ssh_runner.(info) do
      {:ok, %{unix_socket: local_socket} = tunnel} ->
        http_base = ensure_trailing_slash(scheme <> "://d" <> base_path)
        {http_base, %{unix_socket: local_socket}, Map.put(info, :tunnel, tunnel)}

      {:error, reason} ->
        raise ArgumentError,
              "Failed to establish SSH tunnel for #{original}: #{inspect(reason)}"
    end
  end

  defp extract_socket_and_path(%URI{host: host, path: path}) do
    cond do
      host not in [nil, ""] ->
        socket_path = URI.decode_www_form(host)
        {socket_path, ensure_base_path(path)}

      true ->
        combined = ensure_leading_slash(path || "/")

        case Regex.run(~r|^(/.+?\.sock)(/.*)?$|, combined) do
          [_, socket, rest] ->
            base_path = rest || "/"
            {socket, base_path}

          [_, socket] ->
            {socket, "/"}

          nil ->
            raise ArgumentError, "unix-style URLs must include a .sock segment"
        end
    end
  end

  defp extract_ssh_socket_and_path(%URI{path: path, query: query, host: host}) do
    cond do
      path not in [nil, ""] ->
        combined = ensure_leading_slash(path)

        case Regex.run(~r|^(/.+?\.sock)(/.*)?$|, combined) do
          [_, socket, rest] -> {socket, rest || "/"}
          [_, socket] -> {socket, "/"}
          nil -> raise ArgumentError, "ssh URLs must include a remote .sock path"
        end

      query ->
        params = URI.decode_query(query)

        case Map.fetch(params, "socket") do
          {:ok, socket} ->
            base_path = Map.get(params, "path", "/")
            {socket, ensure_leading_slash(base_path)}

          :error ->
            raise ArgumentError,
                  "Unable to determine remote socket for http+ssh URL targeting #{inspect(host)}"
        end

      true ->
        raise ArgumentError,
              "Unable to determine remote socket for http+ssh URL targeting #{inspect(host)}"
    end
  end

  defp ensure_base_path(nil), do: "/"
  defp ensure_base_path(""), do: "/"
  defp ensure_base_path(path), do: path

  defp ensure_leading_slash(value) do
    cond do
      value in [nil, ""] -> "/"
      String.starts_with?(value, "/") -> value
      true -> "/" <> value
    end
  end

  defp decode_query(nil), do: %{}
  defp decode_query(query), do: URI.decode_query(query)

  defp truthy?(value) when value in [true, 1, "1", "true", "TRUE", "True"], do: true
  defp truthy?(_), do: false

  defp cleanup_connection(%{type: :ssh, tunnel: %{cleanup: cleanup}})
       when is_function(cleanup, 0),
       do: cleanup.()

  defp cleanup_connection(_), do: :ok

  defp maybe_put_verify(opts, false), do: opts

  defp maybe_put_verify(opts, true) do
    Keyword.update(opts, :transport_opts, [verify: :verify_peer], fn existing ->
      Keyword.merge(existing, verify: :verify_peer)
    end)
  end

  defp maybe_put_certs(opts, nil), do: opts

  defp maybe_put_certs(opts, path) do
    certs = [
      cacertfile: Path.join(path, "ca.pem"),
      certfile: Path.join(path, "cert.pem"),
      keyfile: Path.join(path, "key.pem")
    ]

    Keyword.update(opts, :transport_opts, certs, fn existing ->
      Keyword.merge(existing, certs)
    end)
  end

  defp normalize_env(nil), do: System.get_env()
  defp normalize_env(env) when is_map(env), do: env
  defp normalize_env(env) when is_list(env), do: Map.new(env)

  defp default_user_agent do
    version =
      case Application.spec(:podman, :vsn) do
        nil -> "dev"
        vsn -> to_string(vsn)
      end

    req_version =
      case Application.spec(:req, :vsn) do
        nil -> "unknown"
        vsn -> to_string(vsn)
      end

    "podman-elixir/#{version} (req/#{req_version})"
  end

  defp default_ssh_runner(_info) do
    case System.get_env("PODMAN_SSH_TUNNEL") do
      nil -> {:error, :ssh_runner_not_configured}
      path -> {:ok, %{unix_socket: path, cleanup: fn -> :ok end}}
    end
  end
end
