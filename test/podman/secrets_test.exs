defmodule Podman.SecretsTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Secrets}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "create encodes payload", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/secrets/create", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["name"] == "demo"
      assert conn.params["labels"] |> Jason.decode!() == %{"app" => "demo"}

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == Base.encode64("secret")

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(201, ~s({"ID":"abc"}))
    end)

    assert {:ok, %{"ID" => "abc"}} =
             Secrets.create(client, "demo", "secret", labels: %{app: "demo"})
  end

  test "delete forwards all param", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "DELETE", "/v5.0.0/libpod/secrets/demo", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["all"] == "true"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(204, "")
    end)

    assert {:ok, :ok} = Secrets.delete(client, "demo", all: true)
  end

  test "exists? handles 404", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/v5.0.0/libpod/secrets/demo/exists", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, true} = Secrets.exists?(client, "demo")

    Bypass.expect_once(bypass, "GET", "/v5.0.0/libpod/secrets/missing/exists", fn conn ->
      Plug.Conn.resp(conn, 404, ~s({"message":"not found"}))
    end)

    assert {:ok, false} = Secrets.exists?(client, "missing")
  end
end
