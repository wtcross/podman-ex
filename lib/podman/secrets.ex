defmodule Podman.Secrets do
  @moduledoc """
  Helpers for the Podman secrets API.
  """

  alias Podman.{Client, Error, RequestOptions}

  @type secret_id :: String.t()

  @error_map %{404 => :not_found, 409 => :conflict, 500 => :server_error}

  @spec list(Client.t(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    Client.get(client, ["libpod", "secrets", "json"], opts)
  end

  @spec inspect(Client.t(), secret_id(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def inspect(%Client{} = client, secret, opts \\ []) do
    Client.get(client, ["libpod", "secrets", secret, "json"], opts)
  end

  @spec create(Client.t(), String.t(), iodata(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(%Client{} = client, name, data, opts \\ []) when is_binary(name) do
    params =
      opts
      |> Client.encode_query([
        {:driver, "driver"},
        {:driver_opts, "driveropts", &RequestOptions.encode_map/1},
        {:labels, "labels", &RequestOptions.encode_map/1}
      ])
      |> Map.put("name", name)

    request_opts =
      opts
      |> Keyword.drop([:driver, :driver_opts, :labels])
      |> Keyword.delete(:params)
      |> Keyword.put(:params, params)
      |> Keyword.put(:body, encode_data(data))
      |> RequestOptions.prepend_header({"content-type", "application/json"})

    Client.post(client, ["libpod", "secrets", "create"], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec delete(Client.t(), secret_id(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def delete(%Client{} = client, secret, opts \\ []) do
    params = Client.encode_query(opts, [{:all, "all"}])

    request_opts = RequestOptions.put_params(opts, params, [:all])

    Client.delete(client, ["libpod", "secrets", secret], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec exists?(Client.t(), secret_id()) :: {:ok, boolean()} | {:error, Error.t()}
  def exists?(%Client{} = client, secret) do
    case Client.get(client, ["libpod", "secrets", secret, "exists"], response: :full) do
      {:ok, %Req.Response{status: 204}} -> {:ok, true}
      {:ok, %Req.Response{status: status}} when status in 200..299 -> {:ok, true}
      {:error, %Error{status: 404}} -> {:ok, false}
      {:error, %Error{} = error} -> {:error, error}
      other -> other
    end
  end

  defp encode_data(data) do
    data
    |> IO.iodata_to_binary()
    |> Base.encode64()
  end
end
