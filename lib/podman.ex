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

  alias Podman.{
    Client,
    Containers,
    Images,
    Kube,
    Machines,
    Networks,
    Pods,
    Quadlets,
    Secrets,
    System,
    Volumes
  }

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

  @doc "Lists networks (`GET /libpod/networks/json`)."
  @spec list_networks(client, keyword()) :: {:ok, list()} | {:error, Podman.Error.t()}
  def list_networks(%Client{} = client, opts \\ []) do
    Networks.list(client, opts)
  end

  @doc "Inspects a network (`GET /libpod/networks/{id}/json`)."
  @spec inspect_network(client, Networks.network_id(), keyword()) ::
          {:ok, map()} | {:error, Podman.Error.t()}
  def inspect_network(%Client{} = client, network, opts \\ []) do
    Networks.inspect(client, network, opts)
  end

  @doc "Creates a network (`POST /libpod/networks/create`)."
  @spec create_network(client, map(), keyword()) :: {:ok, map()} | {:error, Podman.Error.t()}
  def create_network(%Client{} = client, spec, opts \\ []) do
    Networks.create(client, spec, opts)
  end

  @doc "Deletes a network (`DELETE /libpod/networks/{id}`)."
  @spec delete_network(client, Networks.network_id(), keyword()) ::
          {:ok, term()} | {:error, Podman.Error.t()}
  def delete_network(%Client{} = client, network, opts \\ []) do
    Networks.delete(client, network, opts)
  end

  @doc "Checks if a network exists (`GET /libpod/networks/{id}/exists`)."
  @spec network_exists?(client, Networks.network_id()) ::
          {:ok, boolean()} | {:error, Podman.Error.t()}
  def network_exists?(%Client{} = client, network) do
    Networks.exists?(client, network)
  end

  @doc "Connects a container to a network (`POST /libpod/networks/{id}/connect`)."
  @spec network_connect(client, Networks.network_id(), map(), keyword()) ::
          {:ok, term()} | {:error, Podman.Error.t()}
  def network_connect(%Client{} = client, network, attrs, opts \\ []) do
    Networks.connect(client, network, attrs, opts)
  end

  @doc "Disconnects a container from a network (`POST /libpod/networks/{id}/disconnect`)."
  @spec network_disconnect(client, Networks.network_id(), map(), keyword()) ::
          {:ok, term()} | {:error, Podman.Error.t()}
  def network_disconnect(%Client{} = client, network, attrs, opts \\ []) do
    Networks.disconnect(client, network, attrs, opts)
  end

  @doc "Ensures a network exists, creating it if necessary."
  @spec ensure_network(client, String.t(), map(), keyword()) ::
          {:ok, %{status: :created | :existing, network: map()}}
          | {:error, Podman.Error.t()}
  def ensure_network(%Client{} = client, name, spec \\ %{}, opts \\ []) do
    spec = ensure_name(spec, name)

    case create_network(client, spec, opts) do
      {:ok, network} ->
        {:ok, %{status: :created, network: network}}

      {:error, %Podman.Error{reason: :conflict}} ->
        with {:ok, info} <- inspect_network(client, name, opts) do
          {:ok, %{status: :existing, network: info}}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc "Ensures a network is removed, tolerating missing resources."
  @spec ensure_network_deleted(client, String.t(), keyword()) ::
          {:ok, :removed | :missing} | {:error, Podman.Error.t()}
  def ensure_network_deleted(%Client{} = client, name, opts \\ []) do
    case delete_network(client, name, opts) do
      {:ok, _} -> {:ok, :removed}
      {:error, %Podman.Error{reason: :not_found}} -> {:ok, :missing}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Lists secrets (`GET /libpod/secrets/json`)."
  @spec list_secrets(client, keyword()) :: {:ok, list()} | {:error, Podman.Error.t()}
  def list_secrets(%Client{} = client, opts \\ []) do
    Secrets.list(client, opts)
  end

  @doc "Inspects a secret (`GET /libpod/secrets/{id}/json`)."
  @spec inspect_secret(client, Secrets.secret_id(), keyword()) ::
          {:ok, map()} | {:error, Podman.Error.t()}
  def inspect_secret(%Client{} = client, secret, opts \\ []) do
    Secrets.inspect(client, secret, opts)
  end

  @doc "Creates a secret (`POST /libpod/secrets/create`)."
  @spec create_secret(client, String.t(), iodata(), keyword()) ::
          {:ok, map()} | {:error, Podman.Error.t()}
  def create_secret(%Client{} = client, name, data, opts \\ []) do
    Secrets.create(client, name, data, opts)
  end

  @doc "Deletes a secret (`DELETE /libpod/secrets/{id}`)."
  @spec delete_secret(client, Secrets.secret_id(), keyword()) ::
          {:ok, term()} | {:error, Podman.Error.t()}
  def delete_secret(%Client{} = client, secret, opts \\ []) do
    Secrets.delete(client, secret, opts)
  end

  @doc "Checks if a secret exists (`GET /libpod/secrets/{id}/exists`)."
  @spec secret_exists?(client, Secrets.secret_id()) ::
          {:ok, boolean()} | {:error, Podman.Error.t()}
  def secret_exists?(%Client{} = client, secret) do
    Secrets.exists?(client, secret)
  end

  @doc "Lists volumes (`GET /libpod/volumes/json`)."
  @spec list_volumes(client, keyword()) :: {:ok, list()} | {:error, Podman.Error.t()}
  def list_volumes(%Client{} = client, opts \\ []) do
    Volumes.list(client, opts)
  end

  @doc "Inspects a volume (`GET /libpod/volumes/{name}/json`)."
  @spec inspect_volume(client, Volumes.volume_name(), keyword()) ::
          {:ok, map()} | {:error, Podman.Error.t()}
  def inspect_volume(%Client{} = client, name, opts \\ []) do
    Volumes.inspect(client, name, opts)
  end

  @doc "Creates a volume (`POST /libpod/volumes/create`)."
  @spec create_volume(client, map(), keyword()) :: {:ok, map()} | {:error, Podman.Error.t()}
  def create_volume(%Client{} = client, spec, opts \\ []) do
    Volumes.create(client, spec, opts)
  end

  @doc "Deletes a volume (`DELETE /libpod/volumes/{name}`)."
  @spec delete_volume(client, Volumes.volume_name(), keyword()) ::
          {:ok, term()} | {:error, Podman.Error.t()}
  def delete_volume(%Client{} = client, name, opts \\ []) do
    Volumes.delete(client, name, opts)
  end

  @doc "Checks if a volume exists (`GET /libpod/volumes/{name}/exists`)."
  @spec volume_exists?(client, Volumes.volume_name()) ::
          {:ok, boolean()} | {:error, Podman.Error.t()}
  def volume_exists?(%Client{} = client, name) do
    Volumes.exists?(client, name)
  end

  @doc "Ensures a volume exists, creating it if necessary."
  @spec ensure_volume(client, String.t(), map(), keyword()) ::
          {:ok, %{status: :created | :existing, volume: map()}}
          | {:error, Podman.Error.t()}
  def ensure_volume(%Client{} = client, name, spec \\ %{}, opts \\ []) do
    spec = ensure_name(spec, name)

    case create_volume(client, spec, opts) do
      {:ok, volume} ->
        {:ok, %{status: :created, volume: volume}}

      {:error, %Podman.Error{reason: :conflict}} ->
        with {:ok, info} <- inspect_volume(client, name, opts) do
          {:ok, %{status: :existing, volume: info}}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc "Ensures a volume is deleted, tolerating missing volumes."
  @spec ensure_volume_deleted(client, String.t(), keyword()) ::
          {:ok, :removed | :missing} | {:error, Podman.Error.t()}
  def ensure_volume_deleted(%Client{} = client, name, opts \\ []) do
    case delete_volume(client, name, opts) do
      {:ok, _} -> {:ok, :removed}
      {:error, %Podman.Error{reason: :not_found}} -> {:ok, :missing}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Lists pods (`GET /libpod/pods/json`)."
  @spec list_pods(client, keyword()) :: {:ok, list()} | {:error, Podman.Error.t()}
  def list_pods(%Client{} = client, opts \\ []) do
    Pods.list(client, opts)
  end

  @doc "Inspects a pod (`GET /libpod/pods/{id}/json`)."
  @spec inspect_pod(client, Pods.pod_id(), keyword()) :: {:ok, map()} | {:error, Podman.Error.t()}
  def inspect_pod(%Client{} = client, pod_id, opts \\ []) do
    Pods.inspect(client, pod_id, opts)
  end

  @doc "Creates a pod (`POST /libpod/pods/create`)."
  @spec create_pod(client, map(), keyword()) :: {:ok, map()} | {:error, Podman.Error.t()}
  def create_pod(%Client{} = client, spec, opts \\ []) do
    Pods.create(client, spec, opts)
  end

  @doc "Starts a pod (`POST /libpod/pods/{id}/start`)."
  @spec start_pod(client, Pods.pod_id(), keyword()) :: {:ok, term()} | {:error, Podman.Error.t()}
  def start_pod(%Client{} = client, pod_id, opts \\ []) do
    Pods.start(client, pod_id, opts)
  end

  @doc "Stops a pod (`POST /libpod/pods/{id}/stop`)."
  @spec stop_pod(client, Pods.pod_id(), keyword()) :: {:ok, term()} | {:error, Podman.Error.t()}
  def stop_pod(%Client{} = client, pod_id, opts \\ []) do
    Pods.stop(client, pod_id, opts)
  end

  @doc "Deletes a pod (`DELETE /libpod/pods/{id}`)."
  @spec delete_pod(client, Pods.pod_id(), keyword()) :: {:ok, term()} | {:error, Podman.Error.t()}
  def delete_pod(%Client{} = client, pod_id, opts \\ []) do
    Pods.delete(client, pod_id, opts)
  end

  @doc "Checks if a pod exists (`GET /libpod/pods/{id}/exists`)."
  @spec pod_exists?(client, Pods.pod_id()) :: {:ok, boolean()} | {:error, Podman.Error.t()}
  def pod_exists?(%Client{} = client, pod_id) do
    Pods.exists?(client, pod_id)
  end

  @doc "Ensures a pod exists and is started."
  @spec ensure_pod_started(client, map(), keyword()) ::
          {:ok, %{status: :created | :existing, pod: map()}}
          | {:error, Podman.Error.t()}
  def ensure_pod_started(%Client{} = client, spec, opts \\ []) do
    name = fetch_name!(spec, "pod")
    spec = ensure_name(spec, name)

    case create_pod(client, spec, opts) do
      {:ok, pod} ->
        case start_pod(client, pod["Id"] || name, opts) do
          {:ok, _} -> {:ok, %{status: :created, pod: pod}}
          {:error, %Podman.Error{reason: :not_modified}} -> {:ok, %{status: :created, pod: pod}}
          {:error, error} -> {:error, error}
        end

      {:error, %Podman.Error{reason: :conflict}} ->
        with {:ok, info} <- inspect_pod(client, name, opts),
             start_result <- start_pod(client, name, opts) do
          case start_result do
            {:ok, _} ->
              {:ok, %{status: :existing, pod: info}}

            {:error, %Podman.Error{reason: :not_modified}} ->
              {:ok, %{status: :existing, pod: info}}

            {:error, error} ->
              {:error, error}
          end
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc "Ensures a pod is stopped."
  @spec ensure_pod_stopped(client, String.t(), keyword()) ::
          {:ok, :stopped | :already_stopped} | {:error, Podman.Error.t()}
  def ensure_pod_stopped(%Client{} = client, pod_id, opts \\ []) do
    case stop_pod(client, pod_id, opts) do
      {:ok, _} -> {:ok, :stopped}
      {:error, %Podman.Error{reason: :not_modified}} -> {:ok, :already_stopped}
      {:error, error} -> {:error, error}
    end
  end

  defp ensure_name(spec, name) do
    spec
    |> Map.put_new("Name", name)
    |> Map.delete("name")
  end

  defp fetch_name!(spec, resource) do
    spec["Name"] || spec["name"] ||
      raise ArgumentError, "expected #{resource} spec to include \"Name\""
  end

  @doc "Plays a Kubernetes manifest (`POST /libpod/play/kube`)."
  @spec play_kube(client, Kube.manifest(), keyword()) :: {:ok, map()} | {:error, Podman.Error.t()}
  def play_kube(%Client{} = client, manifest, opts \\ []) do
    Kube.play(client, manifest, opts)
  end

  @doc "Tears down resources created from a Kubernetes manifest (`DELETE /libpod/play/kube`)."
  @spec play_kube_down(client, Kube.manifest(), keyword()) ::
          {:ok, map()} | {:error, Podman.Error.t()}
  def play_kube_down(%Client{} = client, manifest, opts \\ []) do
    Kube.down(client, manifest, opts)
  end

  @doc "Generates Kubernetes YAML (`GET /libpod/generate/kube`)."
  @spec generate_kube(client, [String.t()], keyword()) ::
          {:ok, binary()} | {:error, Podman.Error.t()}
  def generate_kube(%Client{} = client, names, opts \\ []) do
    Kube.generate(client, names, opts)
  end

  @doc "Generates systemd quadlet units (`GET /libpod/generate/{name}/systemd`)."
  @spec quadlet_generate(client, String.t(), keyword()) ::
          {:ok, binary()} | {:error, Podman.Error.t()}
  def quadlet_generate(%Client{} = client, name, opts \\ []) do
    Quadlets.generate(client, name, opts)
  end

  @doc "Lists Podman machines (`GET /libpod/machines/json`)."
  @spec list_machines(client, keyword()) :: {:ok, list()} | {:error, Podman.Error.t()}
  def list_machines(%Client{} = client, opts \\ []) do
    Machines.list(client, opts)
  end

  @doc "Inspects a Podman machine (`GET /libpod/machines/{name}/json`)."
  @spec inspect_machine(client, String.t(), keyword()) ::
          {:ok, map()} | {:error, Podman.Error.t()}
  def inspect_machine(%Client{} = client, name, opts \\ []) do
    Machines.inspect(client, name, opts)
  end
end
