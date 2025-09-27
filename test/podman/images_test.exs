defmodule Podman.ImagesTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Images}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "list retrieves image summaries", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.request_path == "/v5.0.0/libpod/images/json"
      assert conn.params["all"] == "true"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s([{"Id":"sha256:abc"}]))
    end)

    assert {:ok, [%{"Id" => "sha256:abc"}]} = Images.list(client, all: true)
  end

  test "pull forwards reference and registry auth header", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["reference"] == "quay.io/demo/app:latest"
      assert conn.params["tlsVerify"] == "false"

      assert Plug.Conn.get_req_header(conn, "x-registry-auth") == ["encoded"]

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"images":["sha256:abc"]}))
    end)

    assert {:ok, %{"images" => ["sha256:abc"]}} =
             Images.pull(client, "quay.io/demo/app:latest",
               tls_verify: false,
               registry_auth: "encoded"
             )
  end

  test "inspect fetches low-level image info", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      assert conn.request_path == "/v5.0.0/libpod/images/sha256:abc/json"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"Id":"sha256:abc"}))
    end)

    assert {:ok, %{"Id" => "sha256:abc"}} = Images.inspect(client, "sha256:abc")
  end
end
