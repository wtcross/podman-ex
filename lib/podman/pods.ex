defmodule Podman.Pods do
  @moduledoc """
  Helpers for interacting with Podman pod endpoints.
  """

  alias Podman.{Client, Error, RequestOptions}

  @type pod_id :: String.t()

  @create_errors %{400 => :bad_request, 404 => :not_found, 409 => :conflict, 500 => :server_error}
  @lifecycle_errors %{
    304 => :not_modified,
    400 => :bad_request,
    404 => :not_found,
    409 => :conflict,
    500 => :server_error
  }

  @spec list(Client.t(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    params =
      Client.encode_query(opts, [
        {:filters, "filters", &Client.encode_filters/1}
      ])

    request_opts = RequestOptions.put_params(opts, params, [:filters])

    Client.get(client, ["libpod", "pods", "json"], request_opts)
  end

  @spec inspect(Client.t(), pod_id(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def inspect(%Client{} = client, pod_id, opts \\ []) do
    Client.get(client, ["libpod", "pods", pod_id, "json"], opts)
  end

  @spec create(Client.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(%Client{} = client, %{} = spec, opts \\ []) do
    request_opts =
      opts
      |> Keyword.delete(:json)
      |> Keyword.put(:json, spec)

    Client.post(client, ["libpod", "pods", "create"], request_opts)
    |> RequestOptions.classify(@create_errors)
  end

  @spec start(Client.t(), pod_id(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def start(%Client{} = client, pod_id, opts \\ []) do
    Client.post(client, ["libpod", "pods", pod_id, "start"], opts)
    |> RequestOptions.classify(@lifecycle_errors)
  end

  @spec stop(Client.t(), pod_id(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def stop(%Client{} = client, pod_id, opts \\ []) do
    params = Client.encode_query(opts, [{:timeout, "t"}])
    request_opts = RequestOptions.put_params(opts, params, [:timeout])

    Client.post(client, ["libpod", "pods", pod_id, "stop"], request_opts)
    |> RequestOptions.classify(@lifecycle_errors)
  end

  @spec delete(Client.t(), pod_id(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def delete(%Client{} = client, pod_id, opts \\ []) do
    params = Client.encode_query(opts, [{:force, "force"}])
    request_opts = RequestOptions.put_params(opts, params, [:force])

    Client.delete(client, ["libpod", "pods", pod_id], request_opts)
    |> RequestOptions.classify(@create_errors)
  end

  @spec exists?(Client.t(), pod_id()) :: {:ok, boolean()} | {:error, Error.t()}
  def exists?(%Client{} = client, pod_id) do
    case Client.get(client, ["libpod", "pods", pod_id, "exists"], response: :full) do
      {:ok, %Req.Response{status: 204}} -> {:ok, true}
      {:ok, %Req.Response{status: status}} when status in 200..299 -> {:ok, true}
      {:error, %Error{status: 404}} -> {:ok, false}
      {:error, %Error{} = error} -> {:error, error}
      other -> other
    end
  end
end
