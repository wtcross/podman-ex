defmodule Podman.Machines do
  @moduledoc """
  Thin wrapper around Podman's experimental machine endpoints.

  Note: Not all Podman services expose machine APIs. Requests may return
  `{:error, %Podman.Error{status: 404}}` if the feature is unavailable.
  """

  alias Podman.{Client, Error}

  @spec list(Client.t(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    Client.get(client, ["libpod", "machines", "json"], opts)
  end

  @spec inspect(Client.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def inspect(%Client{} = client, name, opts \\ []) do
    Client.get(client, ["libpod", "machines", name, "json"], opts)
  end
end
