defmodule PodmanTest do
  use ExUnit.Case, async: true

  doctest Podman

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Podman.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "system_info delegates to Podman.System", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      assert conn.request_path == "/v5.0.0/libpod/info"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"host":{"version":"5.0"}}))
    end)

    assert {:ok, %{"host" => %{"version" => "5.0"}}} = Podman.system_info(client)
  end

  test "list_containers delegates to Podman.Containers", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s([{"Id":"1"}]))
    end)

    assert {:ok, [_]} = Podman.list_containers(client)
  end

  test "pull_image delegates to Podman.Images", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"images":["sha256:1"]}))
    end)

    assert {:ok, %{"images" => ["sha256:1"]}} =
             Podman.pull_image(client, "quay.io/demo/app:latest")
  end
end
