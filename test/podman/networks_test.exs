defmodule Podman.NetworksTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Error, Networks}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "list encodes filters", %{bypass: bypass, client: client} do
    filters = %{"name" => ["demo"]}

    Bypass.expect(bypass, "GET", "/v5.0.0/libpod/networks/json", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert Jason.decode!(conn.params["filters"]) == filters

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s([{"Name":"demo"}]))
    end)

    assert {:ok, [%{"Name" => "demo"}]} = Networks.list(client, filters: filters)
  end

  test "create posts json body", %{bypass: bypass, client: client} do
    payload = %{"Name" => "demo"}

    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/networks/create", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == payload

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"Id":"abc"}))
    end)

    assert {:ok, %{"Id" => "abc"}} = Networks.create(client, payload)
  end

  test "create classifies server errors", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/networks/create", fn conn ->
      Plug.Conn.resp(conn, 500, ~s({"message":"boom"}))
    end)

    assert {:error, %Error{reason: :server_error}} = Networks.create(client, %{})
  end

  test "delete forwards force param", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "DELETE", "/v5.0.0/libpod/networks/demo", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["force"] == "true"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({}))
    end)

    assert {:ok, %{}} = Networks.delete(client, "demo", force: true)
  end

  test "delete classifies not found", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "DELETE", "/v5.0.0/libpod/networks/missing", fn conn ->
      Plug.Conn.resp(conn, 404, ~s({"message":"missing"}))
    end)

    assert {:error, %Error{reason: :not_found}} = Networks.delete(client, "missing")
  end

  test "delete classifies server errors", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "DELETE", "/v5.0.0/libpod/networks/fail", fn conn ->
      Plug.Conn.resp(conn, 500, ~s({"message":"boom"}))
    end)

    assert {:error, %Error{reason: :server_error}} = Networks.delete(client, "fail")
  end

  test "connect sends json body", %{bypass: bypass, client: client} do
    attrs = %{"Container" => "ctr"}

    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/networks/demo/connect", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == attrs

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({}))
    end)

    assert {:ok, %{}} = Networks.connect(client, "demo", attrs)
  end

  test "connect classifies server errors", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/networks/demo/connect", fn conn ->
      Plug.Conn.resp(conn, 500, ~s({"message":"boom"}))
    end)

    assert {:error, %Error{reason: :server_error}} = Networks.connect(client, "demo", %{})
  end

  test "disconnect classifies errors", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "POST", "/v5.0.0/libpod/networks/demo/disconnect", fn conn ->
      Plug.Conn.resp(conn, 404, ~s({"message":"missing"}))
    end)

    assert {:error, %Error{reason: :not_found}} = Networks.disconnect(client, "demo", %{})
  end

  test "exists? interprets 404", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/v5.0.0/libpod/networks/demo/exists", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, true} = Networks.exists?(client, "demo")

    Bypass.expect_once(bypass, "GET", "/v5.0.0/libpod/networks/missing/exists", fn conn ->
      Plug.Conn.resp(conn, 404, ~s({"message":"not found"}))
    end)

    assert {:ok, false} = Networks.exists?(client, "missing")
  end
end
