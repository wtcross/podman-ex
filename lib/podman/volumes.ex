defmodule Podman.Volumes do
  @moduledoc """
  Helpers for Podman's volume endpoints.
  """

  alias Podman.{Client, Error, RequestOptions}

  @error_map %{404 => :not_found, 409 => :conflict, 500 => :server_error}

  @type volume_name :: String.t()

  @spec list(Client.t(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    params =
      Client.encode_query(opts, [
        {:filters, "filters", &Client.encode_filters/1}
      ])

    request_opts = RequestOptions.put_params(opts, params, [:filters])

    Client.get(client, ["libpod", "volumes", "json"], request_opts)
  end

  @spec inspect(Client.t(), volume_name(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def inspect(%Client{} = client, name, opts \\ []) do
    Client.get(client, ["libpod", "volumes", name, "json"], opts)
  end

  @spec create(Client.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(%Client{} = client, %{} = spec, opts \\ []) do
    request_opts =
      opts
      |> Keyword.delete(:json)
      |> Keyword.put(:json, spec)

    Client.post(client, ["libpod", "volumes", "create"], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec delete(Client.t(), volume_name(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def delete(%Client{} = client, name, opts \\ []) do
    params =
      Client.encode_query(opts, [
        {:force, "force"}
      ])

    request_opts = RequestOptions.put_params(opts, params, [:force])

    Client.delete(client, ["libpod", "volumes", name], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec exists?(Client.t(), volume_name()) :: {:ok, boolean()} | {:error, Error.t()}
  def exists?(%Client{} = client, name) do
    case Client.get(client, ["libpod", "volumes", name, "exists"], response: :full) do
      {:ok, %Req.Response{status: 204}} -> {:ok, true}
      {:ok, %Req.Response{status: status}} when status in 200..299 -> {:ok, true}
      {:error, %Error{status: 404}} -> {:ok, false}
      {:error, %Error{} = error} -> {:error, error}
      other -> other
    end
  end
end
