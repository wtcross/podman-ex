defmodule Podman.ClientIntegrationTest do
  use ExUnit.Case, async: false

  alias Podman.Client
  alias Podman

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

  test "plays kube manifests and manages pods", %{podman: podman, api_version: api_version} do
    with_unix_service(podman, fn socket_path ->
      base_url = "http+unix://#{URI.encode_www_form(socket_path)}/v#{api_version}/"
      client = Podman.new(base_url: base_url)

      pod_name = "demo-" <> unique_name("pod")

      manifest = """
      apiVersion: v1
      kind: Pod
      metadata:
        name: #{pod_name}
      spec:
        containers:
        - name: hello
          image: docker.io/library/alpine:3
          command: ["sleep", "5"]
      """

      tar = manifest_to_tar(manifest)

      {:ok, play_report} =
        Podman.play_kube(client, tar, replace: true, content_type: "application/x-tar")

      [%{"ID" => pod_id} | _] = play_report["Pods"]

      assert {:ok, %{"Name" => ^pod_name}} = Podman.inspect_pod(client, pod_id)

      assert {:ok, pods} = Podman.list_pods(client, filters: %{"name" => [pod_name]})

      assert Enum.any?(pods, fn pod ->
               Map.get(pod, "Id") == pod_id || Map.get(pod, "ID") == pod_id
             end)

      assert {:ok, true} = Podman.pod_exists?(client, pod_id)

      assert {:ok, _} = Podman.stop_pod(client, pod_id)
      assert {:ok, _} = Podman.start_pod(client, pod_id)

      assert {:ok, yaml} = Podman.generate_kube(client, [pod_id])
      assert yaml =~ "kind: Pod"

      assert {:ok, unit} = Podman.quadlet_generate(client, pod_id, use_name: true)
      assert unit =~ "[Unit]"

      {:ok, _} =
        Podman.play_kube_down(client, manifest, force: true, content_type: "application/x-yaml")

      down_result =
        Podman.play_kube_down(client, manifest,
          force: true,
          content_type: "application/x-yaml"
        )

      case down_result do
        {:ok, _} -> :ok
        {:error, %Podman.Error{reason: reason}} -> assert reason == :server_error
      end

      # Give Podman a moment to tear down resources
      Process.sleep(200)

      assert {:ok, false} = Podman.pod_exists?(client, pod_id)

      Client.close(client)
    end)
  end

  test "manages networks via API", %{podman: podman, api_version: api_version} do
    with_unix_service(podman, fn socket_path ->
      base_url = "http+unix://#{URI.encode_www_form(socket_path)}/v#{api_version}/"
      client = Podman.new(base_url: base_url)

      network_name = "demo-net-" <> unique_name("net")

      {:ok, network_resp} = Podman.create_network(client, %{"Name" => network_name})

      assert Map.get(network_resp, "name") == network_name or
               Map.get(network_resp, "Name") == network_name

      assert {:ok, true} = Podman.network_exists?(client, network_name)

      {:ok, networks} = Podman.list_networks(client, filters: %{"name" => [network_name]})

      assert Enum.any?(networks, fn net ->
               Map.get(net, "Name") == network_name || Map.get(net, "name") == network_name
             end)

      {:ok, inspected} = Podman.inspect_network(client, network_name)
      assert Map.get(inspected, "name") == network_name

      container = "demo-container-" <> unique_name("ctr")

      with_container(
        podman,
        socket_path,
        container,
        ["--network", "none", "docker.io/library/alpine:3", "sleep", "30"],
        fn _url ->
          connect_result =
            Podman.network_connect(client, network_name, %{"container" => container})

          case connect_result do
            {:ok, %{}} ->
              assert {:ok, %{}} =
                       Podman.network_disconnect(client, network_name, %{"container" => container})

            {:error, %Podman.Error{reason: reason}} ->
              assert reason in [:server_error, :not_found]
          end

          Process.sleep(200)
        end
      )

      {:ok, _} = Podman.delete_network(client, network_name, force: true)
    end)
  end

  test "manages volumes via API", %{podman: podman, api_version: api_version} do
    with_unix_service(podman, fn socket_path ->
      base_url = "http+unix://#{URI.encode_www_form(socket_path)}/v#{api_version}/"
      client = Podman.new(base_url: base_url)

      volume_name = "demo-vol-" <> unique_name("vol")

      {:ok, %{"Name" => ^volume_name}} = Podman.create_volume(client, %{"Name" => volume_name})

      assert {:ok, true} = Podman.volume_exists?(client, volume_name)

      {:ok, volumes} = Podman.list_volumes(client, filters: %{"name" => [volume_name]})
      assert Enum.any?(volumes, &(&1["Name"] == volume_name))

      {:ok, %{"Name" => ^volume_name}} = Podman.inspect_volume(client, volume_name)

      {:ok, _} = Podman.delete_volume(client, volume_name, force: true)
    end)
  end

  test "manages secrets via API", %{podman: podman, api_version: api_version} do
    with_unix_service(podman, fn socket_path ->
      base_url = "http+unix://#{URI.encode_www_form(socket_path)}/v#{api_version}/"
      client = Podman.new(base_url: base_url)

      secret_name = "demo-secret-" <> unique_name("secret")

      {:ok, %{"ID" => secret_id}} =
        Podman.create_secret(client, secret_name, "top-secret", labels: %{app: "demo"})

      assert {:ok, true} = Podman.secret_exists?(client, secret_id)

      {:ok, info} = Podman.inspect_secret(client, secret_id)
      assert get_in(info, ["Spec", "Name"]) == secret_name

      {:ok, _} = Podman.delete_secret(client, secret_id)
    end)
  end

  test "orchestration helpers ensure resources", %{podman: podman, api_version: api_version} do
    with_unix_service(podman, fn socket_path ->
      base_url = "http+unix://#{URI.encode_www_form(socket_path)}/v#{api_version}/"
      client = Podman.new(base_url: base_url)

      # ensure network
      network_name = "ensure-net-" <> unique_name("net")
      assert {:ok, %{status: :created}} = Podman.ensure_network(client, network_name)
      assert {:ok, %{status: :existing}} = Podman.ensure_network(client, network_name)

      # ensure volume
      volume_name = "ensure-vol-" <> unique_name("vol")
      assert {:ok, %{status: :created}} = Podman.ensure_volume(client, volume_name)
      assert {:ok, %{status: :existing}} = Podman.ensure_volume(client, volume_name)

      # ensure pod started
      pod_name = "ensure-pod-" <> unique_name("pod")
      spec = %{"Name" => pod_name}

      assert {:ok, %{status: :created}} = Podman.ensure_pod_started(client, spec)
      assert {:ok, %{status: :existing}} = Podman.ensure_pod_started(client, spec)

      # stop pod idempotently
      assert {:ok, :stopped} = Podman.ensure_pod_stopped(client, pod_name)
      assert {:ok, :already_stopped} = Podman.ensure_pod_stopped(client, pod_name)

      # cleanup
      {:ok, _} = Podman.ensure_pod_stopped(client, pod_name)
      {:ok, _} = Podman.delete_pod(client, pod_name, force: true)
      {:ok, _} = Podman.ensure_volume_deleted(client, volume_name)
      {:ok, _} = Podman.ensure_network_deleted(client, network_name)
    end)
  end

  test "machine endpoints surface service errors", %{podman: podman, api_version: api_version} do
    with_unix_service(podman, fn socket_path ->
      base_url = "http+unix://#{URI.encode_www_form(socket_path)}/v#{api_version}/"
      client = Podman.new(base_url: base_url)

      assert {:error, %Podman.Error{status: status}} = Podman.list_machines(client)
      assert status in [404, 405, 500]
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

  defp manifest_to_tar(manifest) do
    tmp_dir = Path.join(System.tmp_dir!(), "podman-play-" <> unique_name("tar"))
    File.mkdir_p!(tmp_dir)
    tar_path = Path.join(tmp_dir, "content.tar")
    manifest_path = Path.join(tmp_dir, "play.yaml")

    File.write!(manifest_path, manifest)

    :ok =
      :erl_tar.create(
        String.to_charlist(tar_path),
        [{~c"play.yaml", String.to_charlist(manifest_path)}],
        [:compressed]
      )

    tar_binary = File.read!(tar_path)
    File.rm_rf!(tmp_dir)
    tar_binary
  end
end
