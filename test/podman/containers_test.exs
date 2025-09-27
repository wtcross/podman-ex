defmodule Podman.ContainersTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Containers}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "list encodes query params and filters", %{bypass: bypass, client: client} do
    filters = %{"status" => ["running"], "label" => ["app=demo"]}

    Bypass.expect(bypass, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.request_path == "/v5.0.0/libpod/containers/json"
      assert conn.params["all"] == "true"

      assert filters == conn.params["filters"] |> Jason.decode!()

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s([{"Id":"123"}]))
    end)

    assert {:ok, [%{"Id" => "123"}]} =
             Containers.list(client, all: true, filters: filters)
  end

  test "start forwards detach keys", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.params["detachKeys"] == "ctrl-a,ctrl-q"
      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, :ok} = Containers.start(client, "demo", detach_keys: "ctrl-a,ctrl-q")
  end

  test "delete forwards advanced options", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.params["depend"] == "true"
      assert conn.params["force"] == "true"
      assert conn.params["ignore"] == "true"
      assert conn.params["timeout"] == "20"
      assert conn.params["v"] == "true"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"Deleted":["demo"]}))
    end)

    assert {:ok, %{"Deleted" => ["demo"]}} =
             Containers.delete(client, "demo",
               depend: true,
               force: true,
               ignore: true,
               timeout: 20,
               volumes: true
             )
  end
end
