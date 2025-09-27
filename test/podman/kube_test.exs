defmodule Podman.KubeTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Kube}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "play posts manifest with headers and query", %{bypass: bypass, client: client} do
    manifest = "apiVersion: v1" <> "\n"

    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/play/kube", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["annotations"] == Jason.encode!(%{"app" => "demo"})
      assert conn.params["publishPorts"] == "8080:80"
      assert Plug.Conn.get_req_header(conn, "content-type") == ["plain/text"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == manifest

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"pods":[{"Name":"demo"}]}))
    end)

    assert {:ok, %{"pods" => [%{"Name" => "demo"}]}} =
             Kube.play(client, manifest,
               annotations: %{"app" => "demo"},
               publish_ports: ["8080:80"]
             )
  end

  test "down sends manifest and options", %{bypass: bypass, client: client} do
    manifest = "apiVersion: v1"

    Bypass.expect(bypass, "DELETE", "/v5.0.0/libpod/play/kube", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["force"] == "true"
      assert Plug.Conn.get_req_header(conn, "content-type") == ["plain/text"]
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == manifest

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({}))
    end)

    assert {:ok, %{}} = Kube.down(client, manifest, force: true)
  end

  test "generate passes names and options", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "GET", "/v5.0.0/libpod/generate/kube", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["names"] == "pod1,pod2"
      assert conn.params["type"] == "deployment"
      Plug.Conn.resp(conn, 200, "kind: List")
    end)

    assert {:ok, "kind: List"} = Kube.generate(client, ["pod1", "pod2"], type: "deployment")
  end
end
