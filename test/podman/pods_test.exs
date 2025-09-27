defmodule Podman.PodsTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Error, Pods}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "list encodes filters", %{bypass: bypass, client: client} do
    filters = %{"name" => ["demo"]}

    Bypass.expect(bypass, "GET", "/v5.0.0/libpod/pods/json", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert %{"filters" => value} = conn.params
      assert value |> Jason.decode!() == filters

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s([{"Id":"pod"}]))
    end)

    assert {:ok, [%{"Id" => "pod"}]} = Pods.list(client, filters: filters)
  end

  test "create posts json body", %{bypass: bypass, client: client} do
    spec = %{"name" => "example"}

    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/pods/create", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == spec

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(201, ~s({"Id":"abc"}))
    end)

    assert {:ok, %{"Id" => "abc"}} = Pods.create(client, spec)
  end

  test "create classifies conflicts", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/pods/create", fn conn ->
      Plug.Conn.resp(conn, 409, ~s({"message":"exists"}))
    end)

    assert {:error, %Error{reason: :conflict}} = Pods.create(client, %{})
  end

  test "stop includes timeout", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/pods/demo/stop", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["t"] == "5"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({}))
    end)

    assert {:ok, %{} = _} = Pods.stop(client, "demo", timeout: 5)
  end

  test "start classifies already started", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/pods/demo/start", fn conn ->
      Plug.Conn.resp(conn, 304, "")
    end)

    assert {:error, %Error{reason: :not_modified}} = Pods.start(client, "demo")
  end

  test "delete includes force flag", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "DELETE", "/v5.0.0/libpod/pods/demo", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["force"] == "true"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({}))
    end)

    assert {:ok, %{} = _} = Pods.delete(client, "demo", force: true)
  end

  test "exists? handles 204 and 404", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/v5.0.0/libpod/pods/demo/exists", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, true} = Pods.exists?(client, "demo")

    Bypass.expect_once(bypass, "GET", "/v5.0.0/libpod/pods/missing/exists", fn conn ->
      Plug.Conn.resp(conn, 404, ~s({"cause":"no such pod"}))
    end)

    assert {:ok, false} = Pods.exists?(client, "missing")
  end
end
