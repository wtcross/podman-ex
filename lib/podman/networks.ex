defmodule Podman.Networks do
  @moduledoc """
  Helpers for Podman's network endpoints.
  """

  alias Podman.{Client, Error, RequestOptions}

  @error_map %{404 => :not_found, 409 => :conflict, 500 => :server_error}

  @type network_id :: String.t()

  @spec list(Client.t(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    params =
      Client.encode_query(opts, [
        {:filters, "filters", &Client.encode_filters/1}
      ])

    request_opts = RequestOptions.put_params(opts, params, [:filters])

    Client.get(client, ["libpod", "networks", "json"], request_opts)
  end

  @spec inspect(Client.t(), network_id(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def inspect(%Client{} = client, network, opts \\ []) do
    Client.get(client, ["libpod", "networks", network, "json"], opts)
  end

  @spec create(Client.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(%Client{} = client, %{} = spec, opts \\ []) do
    request_opts =
      opts
      |> Keyword.delete(:json)
      |> Keyword.put(:json, spec)

    Client.post(client, ["libpod", "networks", "create"], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec delete(Client.t(), network_id(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def delete(%Client{} = client, network, opts \\ []) do
    params = Client.encode_query(opts, [{:force, "force"}])

    request_opts = RequestOptions.put_params(opts, params, [:force])

    Client.delete(client, ["libpod", "networks", network], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec connect(Client.t(), network_id(), map(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def connect(%Client{} = client, network, %{} = attrs, opts \\ []) do
    request_opts =
      opts
      |> Keyword.delete(:json)
      |> Keyword.put(:json, attrs)

    Client.post(client, ["libpod", "networks", network, "connect"], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec disconnect(Client.t(), network_id(), map(), keyword()) ::
          {:ok, term()} | {:error, Error.t()}
  def disconnect(%Client{} = client, network, %{} = attrs, opts \\ []) do
    request_opts =
      opts
      |> Keyword.delete(:json)
      |> Keyword.put(:json, attrs)

    Client.post(client, ["libpod", "networks", network, "disconnect"], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec exists?(Client.t(), network_id()) :: {:ok, boolean()} | {:error, Error.t()}
  def exists?(%Client{} = client, network) do
    case Client.get(client, ["libpod", "networks", network, "exists"], response: :full) do
      {:ok, %Req.Response{status: 204}} -> {:ok, true}
      {:ok, %Req.Response{status: status}} when status in 200..299 -> {:ok, true}
      {:error, %Error{status: 404}} -> {:ok, false}
      {:error, %Error{} = error} -> {:error, error}
      other -> other
    end
  end
end
