defmodule Podman.VolumesTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Error, Volumes}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "list encodes filters", %{bypass: bypass, client: client} do
    filters = %{"name" => ["demo"]}

    Bypass.expect(bypass, "GET", "/v5.0.0/libpod/volumes/json", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert Jason.decode!(conn.params["filters"]) == filters

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s([{"Name":"demo"}]))
    end)

    assert {:ok, [%{"Name" => "demo"}]} = Volumes.list(client, filters: filters)
  end

  test "create posts json body", %{bypass: bypass, client: client} do
    spec = %{"Name" => "demo"}

    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/volumes/create", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == spec

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(201, ~s({"Name":"demo"}))
    end)

    assert {:ok, %{"Name" => "demo"}} = Volumes.create(client, spec)
  end

  test "create classifies server errors", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/volumes/create", fn conn ->
      Plug.Conn.resp(conn, 500, ~s({"message":"fail"}))
    end)

    assert {:error, %Error{reason: :server_error}} = Volumes.create(client, %{})
  end

  test "delete forwards force", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "DELETE", "/v5.0.0/libpod/volumes/demo", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["force"] == "true"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(204, "")
    end)

    assert {:ok, :ok} = Volumes.delete(client, "demo", force: true)
  end

  test "delete classifies conflict", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "DELETE", "/v5.0.0/libpod/volumes/busy", fn conn ->
      Plug.Conn.resp(conn, 409, ~s({"message":"in use"}))
    end)

    assert {:error, %Error{reason: :conflict}} = Volumes.delete(client, "busy")
  end

  test "exists? reflects 404", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/v5.0.0/libpod/volumes/demo/exists", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, true} = Volumes.exists?(client, "demo")

    Bypass.expect_once(bypass, "GET", "/v5.0.0/libpod/volumes/missing/exists", fn conn ->
      Plug.Conn.resp(conn, 404, ~s({"message":"not found"}))
    end)

    assert {:ok, false} = Volumes.exists?(client, "missing")
  end
end
