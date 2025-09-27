defmodule Podman do
  @moduledoc """
  Public entry point for interacting with the Podman REST API.

  This module provides a small, ergonomic façade over the lower-level
  `Podman.Client` helpers and the resource-specific modules such as
  `Podman.System`, `Podman.Containers`, and `Podman.Images`.

  ```elixir
  client = Podman.new(base_url: "http://localhost:8080/v5.0.0/")

  {:ok, info} = Podman.system_info(client)
  {:ok, containers} = Podman.list_containers(client, all: true)
  {:ok, _pull} = Podman.pull_image(client, "quay.io/podman/hello")
  ```
  """

  alias Podman.{Client, Containers, Images, System}

  @typedoc "Opaque client handle used by all Podman helper modules."
  @type client :: Client.t()

  @doc """
  Builds a new `Podman.Client` using the provided options.

  See `Podman.Client.new/1` for supported options.
  """
  @spec new(keyword()) :: client
  def new(opts \\ []) do
    Client.new(opts)
  end

  @doc "Convenience wrapper around `Podman.Client.request/4`."
  @spec request(client, atom(), String.t() | [String.Chars.t()], keyword()) ::
          {:ok, term()} | {:error, Podman.Error.t()}
  def request(%Client{} = client, method, path, opts \\ []) do
    Client.request(client, method, path, opts)
  end

  @doc "Gets system information (`GET /libpod/info`)."
  @spec system_info(client, keyword()) :: {:ok, map()} | {:error, Podman.Error.t()}
  def system_info(%Client{} = client, opts \\ []) do
    System.info(client, opts)
  end

  @doc "Gets component version details (`GET /libpod/version`)."
  @spec system_version(client, keyword()) :: {:ok, map()} | {:error, Podman.Error.t()}
  def system_version(%Client{} = client, opts \\ []) do
    System.version(client, opts)
  end

  @doc "Pings the Podman service (`GET /libpod/_ping`)."
  @spec system_ping(client, keyword()) :: {:ok, map()} | {:error, Podman.Error.t()}
  def system_ping(%Client{} = client, opts \\ []) do
    System.ping(client, opts)
  end

  @doc "Lists containers (`GET /libpod/containers/json`)."
  @spec list_containers(client, keyword()) :: {:ok, list()} | {:error, Podman.Error.t()}
  def list_containers(%Client{} = client, opts \\ []) do
    Containers.list(client, opts)
  end

  @doc "Inspects a container (`GET /libpod/containers/{id}/json`)."
  @spec inspect_container(client, Containers.container_id(), keyword()) ::
          {:ok, map()} | {:error, Podman.Error.t()}
  def inspect_container(%Client{} = client, container_id, opts \\ []) do
    Containers.inspect(client, container_id, opts)
  end

  @doc "Creates a container (`POST /libpod/containers/create`)."
  @spec create_container(client, map(), keyword()) :: {:ok, map()} | {:error, Podman.Error.t()}
  def create_container(%Client{} = client, spec, opts \\ []) do
    Containers.create(client, spec, opts)
  end

  @doc "Starts a container (`POST /libpod/containers/{id}/start`)."
  @spec start_container(client, Containers.container_id(), keyword()) ::
          {:ok, term()} | {:error, Podman.Error.t()}
  def start_container(%Client{} = client, container_id, opts \\ []) do
    Containers.start(client, container_id, opts)
  end

  @doc "Stops a container (`POST /libpod/containers/{id}/stop`)."
  @spec stop_container(client, Containers.container_id(), keyword()) ::
          {:ok, term()} | {:error, Podman.Error.t()}
  def stop_container(%Client{} = client, container_id, opts \\ []) do
    Containers.stop(client, container_id, opts)
  end

  @doc "Deletes a container (`DELETE /libpod/containers/{id}`)."
  @spec delete_container(client, Containers.container_id(), keyword()) ::
          {:ok, term()} | {:error, Podman.Error.t()}
  def delete_container(%Client{} = client, container_id, opts \\ []) do
    Containers.delete(client, container_id, opts)
  end

  @doc "Lists local images (`GET /libpod/images/json`)."
  @spec list_images(client, keyword()) :: {:ok, list()} | {:error, Podman.Error.t()}
  def list_images(%Client{} = client, opts \\ []) do
    Images.list(client, opts)
  end

  @doc "Inspects an image (`GET /libpod/images/{name}/json`)."
  @spec inspect_image(client, Images.image_ref(), keyword()) ::
          {:ok, map()} | {:error, Podman.Error.t()}
  def inspect_image(%Client{} = client, image_ref, opts \\ []) do
    Images.inspect(client, image_ref, opts)
  end

  @doc "Pulls an image (`POST /libpod/images/pull`)."
  @spec pull_image(client, Images.image_ref(), keyword()) ::
          {:ok, map()} | {:error, Podman.Error.t()}
  def pull_image(%Client{} = client, reference, opts \\ []) do
    Images.pull(client, reference, opts)
  end
end
