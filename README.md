# Podman Elixir Client

Lightweight Elixir bindings for Podman's REST API built on top of [`Req`](https://hexdocs.pm/req/readme.html).

## Getting Started

Add the dependency to `mix.exs`:

```elixir
def deps do
  [
    {:podman, path: "../podman-ex"}
  ]
end
```

Start the OTP application so Finch (used by `Req`) is supervised:

```elixir
{:ok, _} = Application.ensure_all_started(:podman)
```

## Creating a Client

### Using `Client.new/1`

```elixir
alias Podman.Client

client =
  Client.new(
    base_url: "http://127.0.0.1:8080/v5.0.0/",
    headers: ["x-client-id": "demo"]
  )
```

`Client.new/1` normalises `http`, `tcp`, `http+unix`, and `http+ssh` URLs automatically. For SSH connections pass an `:ssh_runner` callback that returns a local unix socket tunnel.

### Using `Client.from_env/1`

```elixir
client = Client.from_env()
```

`from_env/1` mirrors the Docker / Podman CLI behaviour. It looks at `CONTAINER_HOST`/`DOCKER_HOST` for the base URL and respects TLS variables like `CONTAINER_TLS_VERIFY` and `CONTAINER_CERT_PATH`.

## Performing Requests

Use the high-level façade or the underlying modules:

```elixir
client = Podman.new()
{:ok, info} = Podman.system_info(client)
{:ok, containers} = Podman.list_containers(client, all: true)
{:ok, images} = Podman.list_images(client)
```

Lower-level helpers return `{:ok, body}` tuples or `{:error, %Podman.Error{}}` for HTTP/transport problems.

## Pods

Pods are managed via the same client:

```elixir
{:ok, pods} = Podman.list_pods(client)
{:ok, created} = Podman.create_pod(client, %{"Name" => "demo"})
{:ok, _} = Podman.start_pod(client, created["Id"])
{:ok, true} = Podman.pod_exists?(client, created["Id"])
{:ok, _} = Podman.delete_pod(client, created["Id"], force: true)
```

High-level helpers offer idempotent orchestration:

```elixir
{:ok, %{status: :created}} = Podman.ensure_network(client, "demo-net")
{:ok, %{status: :existing}} = Podman.ensure_network(client, "demo-net")
{:ok, %{status: :created}} = Podman.ensure_volume(client, "demo-vol")
{:ok, %{status: :existing}} = Podman.ensure_pod_started(client, %{"Name" => "demo"})
{:ok, :already_stopped} = Podman.ensure_pod_stopped(client, "demo")
{:ok, :removed} = Podman.ensure_volume_deleted(client, "demo-vol")
```

## Networks & Volumes

Create isolated networks or persistent volumes directly from the API:

```elixir
{:ok, %{"Id" => net_id}} = Podman.create_network(client, %{"Name" => "demo-net"})
{:ok, true} = Podman.network_exists?(client, "demo-net")
{:ok, _} = Podman.delete_network(client, "demo-net", force: true)

{:ok, %{"Name" => vol_name}} = Podman.create_volume(client, %{"Name" => "demo-vol"})
{:ok, _} = Podman.delete_volume(client, vol_name, force: true)
```

## Secrets

Secrets accept plain text input; the client converts to the base64 format required by the API:

```elixir
{:ok, %{"ID" => id}} = Podman.create_secret(client, "api-token", "super-secret", labels: %{app: "demo"})
{:ok, true} = Podman.secret_exists?(client, id)
{:ok, _} = Podman.delete_secret(client, id)
```

## Registry Authentication

Protected registries (such as `registry.redhat.io`) require credentials. Generate the base64-encoded auth payload (same as Docker) and supply it when pulling:

```elixir
auth = %{username: "user", password: "pass"}
Podman.pull_image(client, "registry.redhat.io/ubi10/ubi:10.0", registry_auth: auth)
```

`registry_auth` accepts either a pre-encoded base64 string or a map/keyword list that will be JSON encoded and base64 encoded automatically. Alternatively, set `REGISTRY_AUTH_FILE` or log in ahead of time with the Podman CLI; the API will then reuse the stored credentials.

## Kubernetes Play Commands

Render manifests with `play kube`, tear them down, or generate YAML from running pods:

```elixir
manifest = File.read!("pod.yaml")
{:ok, report} = Podman.play_kube(client, manifest, replace: true)
{:ok, yaml} = Podman.generate_kube(client, ["demo-pod"], type: "deployment")
{:ok, _} = Podman.play_kube_down(client, manifest, force: true)
```

`Podman.play_kube/3` accepts the manifest as a string or iodata and exposes the query parameters from the REST API (e.g. `publish_ports`, `annotations`, `start: false`).

## Quadlets & Machines

Generate systemd quadlet units with:

```elixir
{:ok, units} = Podman.quadlet_generate(client, pod_id, use_name: true)
```

Machine APIs are experimental; the helper functions (`Podman.list_machines/2`, `Podman.inspect_machine/3`) will raise a `Podman.Error` if the service does not expose these endpoints.

## Running the Demo Script

A convenience script shows the full flow:

```
mix run scripts/pull_demo.exs --image quay.io/podman/hello
```

Use `--scheme tcp` to expose the service on a TCP port, and `--registry-auth` to supply a base64 auth header for secure registries.

## Testing

```
mix test
```

Integration tests in `test/podman/client_integration_test.exs` expect a local `podman` binary.
