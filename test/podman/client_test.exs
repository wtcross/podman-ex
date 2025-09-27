defmodule Podman.ClientTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Error}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "performs GET requests and decodes JSON bodies", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      assert conn.request_path == "/v5.0.0/libpod/info"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"hello":"world"}))
    end)

    assert {:ok, %{"hello" => "world"}} = Client.get(client, ["libpod", "info"])
  end

  test "returns :ok for empty success bodies", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      assert conn.request_path == "/v5.0.0/libpod/containers/demo/start"
      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, :ok} = Client.post(client, ["libpod", "containers", "demo", "start"], [])
  end

  test "wraps non-2xx responses in Podman.Error", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(404, ~s({"message":"not found"}))
    end)

    assert {:error, %Error{status: 404, body: %{"message" => "not found"}}} =
             Client.get(client, ["libpod", "missing"])
  end

  test "supports http+unix connections with encoded socket" do
    client = Client.new(base_url: "http+unix://%2Ftmp%2Fpodman.sock/v5.0.0/")

    assert client.base_url == "http://d/v5.0.0/"
    assert client.request.options[:unix_socket] == "/tmp/podman.sock"
    assert %{type: :unix, socket_path: "/tmp/podman.sock"} = client.connection
  end

  test "supports http+unix connections with inline socket path" do
    client = Client.new(base_url: "http+unix:///run/podman/podman.sock/v5.0.0/")

    assert client.base_url == "http://d/v5.0.0/"
    assert client.request.options[:unix_socket] == "/run/podman/podman.sock"
  end

  test "normalises tcp schemes to http" do
    client = Client.new(base_url: "tcp://localhost:8081/v5.0.0/")

    assert client.base_url == "http://localhost:8081/v5.0.0/"
    assert client.connection.type == :tcp
  end

  test "supports http+ssh connections via custom runner" do
    parent = self()

    runner = fn info ->
      assert info.remote_socket == "/run/podman/podman.sock"
      assert info.host == "example.com"

      {:ok,
       %{
         unix_socket: "/tmp/podman-forward.sock",
         cleanup: fn -> send(parent, :ssh_cleanup) end
       }}
    end

    client =
      Client.new(
        base_url: "http+ssh://root@example.com/run/podman/podman.sock/v5.0.0/",
        ssh_runner: runner
      )

    assert client.base_url == "http://d/v5.0.0/"
    assert client.request.options[:unix_socket] == "/tmp/podman-forward.sock"
    assert %{type: :ssh, host: "example.com"} = client.connection

    Client.close(client)
    assert_receive :ssh_cleanup
  end

  test "from_env builds unix client" do
    env = %{"CONTAINER_HOST" => "unix:///run/podman/podman.sock"}

    client = Client.from_env(env: env)

    assert client.base_url == "http://d/"
    assert client.connection.type == :unix
    assert client.request.options[:unix_socket] == "/run/podman/podman.sock"
  end

  test "from_env merges request options" do
    env = %{
      "DOCKER_HOST" => "tcp://localhost:9000",
      "DOCKER_TLS_VERIFY" => "1",
      "DOCKER_CERT_PATH" => "/tmp/certs"
    }

    client =
      Client.from_env(
        env: env,
        request_options: [connect_options: [transport_opts: [verify: :verify_none]]]
      )

    assert client.base_url == "http://localhost:9000/"
    assert client.connection.type == :tcp

    connect_options = client.request.options[:connect_options]
    assert Keyword.get(connect_options, :transport_opts)[:verify] == :verify_peer
    assert Keyword.get(connect_options, :transport_opts)[:cacertfile] == "/tmp/certs/ca.pem"
  end

  test "injects registry auth header" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    auth = %{username: "user", password: "pass"}

    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/images/pull", fn conn ->
      assert [header] = Plug.Conn.get_req_header(conn, "x-registry-auth")

      decoded =
        header
        |> Base.decode64!()
        |> Jason.decode!()

      assert decoded == %{"username" => "user", "password" => "pass"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({}))
    end)

    assert {:ok, %{}} =
             Client.post(client, ["libpod", "images", "pull"],
               registry_auth: auth,
               json: %{}
             )
  end
end
