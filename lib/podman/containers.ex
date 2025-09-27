defmodule Podman.Containers do
  @moduledoc """
  Client functions for container-related Podman endpoints based on the Swagger
  specification under the `containers` tag.
  """

  alias Podman.{Client, Error}

  @type container_id :: String.t()

  @spec list(Client.t(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    params =
      Client.encode_query(opts, [
        {:all, "all"},
        {:limit, "limit"},
        {:namespace, "namespace"},
        {:pod, "pod"},
        {:size, "size"},
        {:sync, "sync"},
        {:filters, "filters", &Client.encode_filters/1}
      ])

    request_opts =
      put_params(opts, params, [:all, :limit, :namespace, :pod, :size, :sync, :filters])

    Client.get(client, ["libpod", "containers", "json"], request_opts)
  end

  @spec inspect(Client.t(), container_id(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def inspect(%Client{} = client, container_id, opts \\ []) do
    params = Client.encode_query(opts, [{:size, "size"}])
    request_opts = put_params(opts, params, [:size])

    Client.get(client, ["libpod", "containers", container_id, "json"], request_opts)
  end

  @spec create(Client.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(%Client{} = client, %{} = spec, opts \\ []) do
    request_opts =
      opts
      |> Keyword.delete(:json)
      |> Keyword.put(:json, spec)

    Client.post(client, ["libpod", "containers", "create"], request_opts)
  end

  @spec start(Client.t(), container_id(), keyword()) :: {:ok, :ok | any()} | {:error, Error.t()}
  def start(%Client{} = client, container_id, opts \\ []) do
    params = Client.encode_query(opts, [{:detach_keys, "detachKeys"}])
    request_opts = put_params(opts, params, [:detach_keys])

    Client.post(client, ["libpod", "containers", container_id, "start"], request_opts)
  end

  @spec stop(Client.t(), container_id(), keyword()) :: {:ok, :ok | any()} | {:error, Error.t()}
  def stop(%Client{} = client, container_id, opts \\ []) do
    params =
      Client.encode_query(opts, [
        {:timeout, "timeout"},
        {:ignore, "Ignore"}
      ])

    request_opts = put_params(opts, params, [:timeout, :ignore])

    Client.post(client, ["libpod", "containers", container_id, "stop"], request_opts)
  end

  @spec delete(Client.t(), container_id(), keyword()) :: {:ok, :ok | any()} | {:error, Error.t()}
  def delete(%Client{} = client, container_id, opts \\ []) do
    params =
      Client.encode_query(opts, [
        {:depend, "depend"},
        {:force, "force"},
        {:ignore, "ignore"},
        {:timeout, "timeout"},
        {:volumes, "v"}
      ])

    request_opts = put_params(opts, params, [:depend, :force, :ignore, :timeout, :volumes])

    Client.delete(client, ["libpod", "containers", container_id], request_opts)
  end

  defp put_params(opts, params, drop_keys) do
    opts
    |> Keyword.drop(drop_keys)
    |> Keyword.delete(:params)
    |> maybe_put(:params, params)
  end

  defp maybe_put(keyword_list, _key, params) when params == %{}, do: keyword_list
  defp maybe_put(keyword_list, key, params), do: Keyword.put(keyword_list, key, params)
end
