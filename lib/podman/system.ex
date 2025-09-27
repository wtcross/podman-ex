defmodule Podman.System do
  @moduledoc """
  Access to Podman's system endpoints as defined in the libpod Swagger spec.

  Functions in this module map 1:1 to documented operations such as
  `/libpod/info`, `/libpod/_ping`, and `/libpod/version`.
  """

  alias Podman.{Client, Error}

  @spec info(Client.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def info(%Client{} = client, opts \\ []) do
    Client.get(client, ["libpod", "info"], opts)
  end

  @spec version(Client.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def version(%Client{} = client, opts \\ []) do
    Client.get(client, ["libpod", "version"], opts)
  end

  @spec ping(Client.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def ping(%Client{} = client, opts \\ []) do
    default_mapper = fn %Req.Response{body: body, headers: headers, status: status} ->
      %{body: body, headers: headers, status: status}
    end

    opts = Keyword.put_new(opts, :response, default_mapper)

    Client.get(client, ["libpod", "_ping"], opts)
  end
end
