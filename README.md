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

## Registry Authentication

Protected registries (such as `registry.redhat.io`) require credentials. Generate the base64-encoded auth payload (same as Docker) and supply it when pulling:

```elixir
auth = Base.encode64(Jason.encode!(%{username: "user", password: "pass"}))
Podman.pull_image(client, "registry.redhat.io/ubi10/ubi:10.0", registry_auth: auth)
```

Alternatively, set `REGISTRY_AUTH_FILE` or log in ahead of time with the Podman CLI; the API will then reuse the stored credentials.

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
