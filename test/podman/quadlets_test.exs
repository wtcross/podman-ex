defmodule Podman.QuadletsTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Quadlets}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "generate forwards query params", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "GET", "/v5.0.0/libpod/generate/demo/systemd", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["useName"] == "true"
      assert conn.params["after"] == "network.target"

      Plug.Conn.resp(conn, 200, "[Unit]\nDescription=demo")
    end)

    assert {:ok, body} =
             Quadlets.generate(client, "demo", use_name: true, after: "network.target")

    assert body =~ "[Unit]"
  end
end
