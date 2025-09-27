defmodule Podman.SystemTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, System}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "info hits the documented endpoint", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      assert conn.request_path == "/v5.0.0/libpod/info"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"host": {"arch": "amd64"}}))
    end)

    assert {:ok, %{"host" => %{"arch" => "amd64"}}} = System.info(client)
  end

  test "ping returns response metadata", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("libpod-api-version", "5.0.0")
      |> Plug.Conn.resp(200, "OK")
    end)

    assert {:ok, %{body: "OK", headers: headers, status: 200}} = System.ping(client)
    assert Map.get(headers, "libpod-api-version") == ["5.0.0"]
  end
end
