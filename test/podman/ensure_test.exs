defmodule Podman.EnsureTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Podman.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "ensure_network creates when missing", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn
      %Plug.Conn{method: "POST", request_path: "/v5.0.0/libpod/networks/create"} = conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["Name"] == "demo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"Name":"demo"}))
    end)

    assert {:ok, %{status: :created, network: %{"Name" => "demo"}}} =
             Podman.ensure_network(client, "demo")
  end

  test "ensure_network returns existing on conflict", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn
      %Plug.Conn{method: "POST", request_path: "/v5.0.0/libpod/networks/create"} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, ~s({"message":"exists"}))

      %Plug.Conn{method: "GET", request_path: "/v5.0.0/libpod/networks/demo/json"} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"Name":"demo"}))
    end)

    assert {:ok, %{status: :existing, network: %{"Name" => "demo"}}} =
             Podman.ensure_network(client, "demo")
  end

  test "ensure_network_deleted tolerates missing", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn
      %Plug.Conn{method: "DELETE", request_path: "/v5.0.0/libpod/networks/demo"} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, ~s({"message":"missing"}))
    end)

    assert {:ok, :missing} = Podman.ensure_network_deleted(client, "demo")
  end

  test "ensure_volume handles conflicts", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn
      %Plug.Conn{method: "POST", request_path: "/v5.0.0/libpod/volumes/create"} = conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["Name"] == "vol"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, ~s({"message":"exists"}))

      %Plug.Conn{method: "GET", request_path: "/v5.0.0/libpod/volumes/vol/json"} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"Name":"vol"}))
    end)

    assert {:ok, %{status: :existing, volume: %{"Name" => "vol"}}} =
             Podman.ensure_volume(client, "vol")
  end

  test "ensure_volume_deleted returns removed", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn
      %Plug.Conn{method: "DELETE", request_path: "/v5.0.0/libpod/volumes/vol"} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(204, "")
    end)

    assert {:ok, :removed} = Podman.ensure_volume_deleted(client, "vol")
  end

  test "ensure_pod_started creates and starts", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn
      %Plug.Conn{method: "POST", request_path: "/v5.0.0/libpod/pods/create"} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, ~s({"Id":"123"}))

      %Plug.Conn{method: "POST", request_path: "/v5.0.0/libpod/pods/123/start"} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({}))
    end)

    assert {:ok, %{status: :created}} =
             Podman.ensure_pod_started(client, %{"Name" => "pod"})
  end

  test "ensure_pod_started handles existing pod", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn
      %Plug.Conn{method: "POST", request_path: "/v5.0.0/libpod/pods/create"} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, ~s({"message":"exists"}))

      %Plug.Conn{method: "GET", request_path: "/v5.0.0/libpod/pods/pod/json"} = conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"Id":"pod"}))

      %Plug.Conn{method: "POST", request_path: "/v5.0.0/libpod/pods/pod/start"} = conn ->
        Plug.Conn.resp(conn, 304, "")
    end)

    assert {:ok, %{status: :existing}} = Podman.ensure_pod_started(client, %{"Name" => "pod"})
  end

  test "ensure_pod_stopped handles already stopped", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn
      %Plug.Conn{method: "POST", request_path: "/v5.0.0/libpod/pods/pod/stop"} = conn ->
        Plug.Conn.resp(conn, 304, "")
    end)

    assert {:ok, :already_stopped} = Podman.ensure_pod_stopped(client, "pod")
  end
end
