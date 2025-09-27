defmodule Podman.MachinesTest do
  use ExUnit.Case, async: true

  alias Podman.{Client, Machines, Error}

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/v5.0.0/"
    client = Client.new(base_url: base_url)

    {:ok, bypass: bypass, client: client}
  end

  test "list proxies errors", %{bypass: bypass, client: client} do
    Bypass.expect(bypass, "GET", "/v5.0.0/libpod/machines/json", fn conn ->
      Plug.Conn.resp(conn, 404, ~s({"message":"not implemented"}))
    end)

    assert {:error, %Error{status: 404}} = Machines.list(client)
  end
end
