defmodule Podman.ClientIntegrationTest do
  use ExUnit.Case, async: false

  alias Podman.Client

  import Podman.IntegrationCase

  @moduletag :integration

  setup_all do
    podman = System.find_executable("podman") || flunk("podman executable not found in PATH")

    api_version = detect_api_version(podman)

    {:ok, podman: podman, api_version: api_version}
  end

  test "retrieves system info over tcp", %{podman: podman, api_version: api_version} do
    with_tcp_service(podman, fn port ->
      base_url = "http://127.0.0.1:#{port}/v#{api_version}/"
      client = Client.new(base_url: base_url)

      assert {:ok, %{"host" => %{} = host}} = Client.get(client, ["libpod", "info"])
      assert Map.has_key?(host, "arch")
    end)
  end

  test "retrieves system info over unix socket", %{podman: podman, api_version: api_version} do
    with_unix_service(podman, fn socket_path ->
      encoded = URI.encode_www_form(socket_path)
      base_url = "http+unix://#{encoded}/v#{api_version}/"
      client = Client.new(base_url: base_url)

      assert {:ok, %{"host" => %{} = host}} = Client.get(client, ["libpod", "info"])
      assert Map.has_key?(host, "arch")
    end)
  end

  test "retrieves system info over http+ssh with custom runner", %{
    podman: podman,
    api_version: api_version
  } do
    parent = self()

    with_unix_service(podman, fn socket_path ->
      base_url = "http+ssh://localhost#{socket_path}/v#{api_version}/"

      runner = fn info ->
        assert info.remote_socket == socket_path
        assert info.host == "localhost"

        {:ok,
         %{
           unix_socket: socket_path,
           cleanup: fn -> send(parent, :ssh_cleanup) end
         }}
      end

      client = Client.new(base_url: base_url, ssh_runner: runner)

      assert {:ok, %{"host" => %{} = host}} = Client.get(client, ["libpod", "info"])
      assert Map.has_key?(host, "arch")

      Client.close(client)
      assert_receive :ssh_cleanup
    end)
  end

  defp detect_api_version(podman) do
    candidates = [
      {"version", ["Client", "APIVersion"]},
      {"version", ["Server", "APIVersion"]},
      {"info", ["Version", "APIVersion"]}
    ]

    Enum.reduce_while(candidates, "5.0.0", fn {command, path}, _acc ->
      case json_value(podman, command, path) do
        {:ok, version} -> {:halt, version}
        :error -> {:cont, "5.0.0"}
      end
    end)
  end

  defp json_value(podman, command, path) do
    args = [command, "--format", "{{json .}}"]

    case System.cmd(podman, args) do
      {output, 0} ->
        with {:ok, decoded} <- Jason.decode(output),
             value when is_binary(value) <- get_in(decoded, path) do
          {:ok, String.trim(value)}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end
end
