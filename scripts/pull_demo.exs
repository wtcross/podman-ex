#!/usr/bin/env elixir

Mix.Task.run("app.start")

alias Podman.Client

case System.get_env("PODMAN_PULL_VERBOSE") do
  "1" -> Application.put_env(:logger, :level, :debug)
  _ -> :ok
end

# -- implementation --------------------------------------------------------

defmodule PullDemo do
  @default_image "registry.redhat.io/ubi10/ubi:10.0"

  @api_version_candidates [
    {"version", ["Client", "APIVersion"]},
    {"version", ["Server", "APIVersion"]},
    {"info", ["Version", "APIVersion"]}
  ]

  @service_timeout 5_000

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          image: :string,
          registry_auth: :string,
          scheme: :string,
          keep_service: :boolean
        ],
        aliases: [i: :image, r: :registry_auth, s: :scheme]
      )

    image = opts[:image] || @default_image
    scheme = opts[:scheme] || "unix"

    podman = System.find_executable("podman") || raise "podman executable not found in PATH"

    {address, service_resource} = start_service(podman, scheme)

    try do
      wait_for_service(address, scheme, @service_timeout)

      api_version = detect_api_version(podman)
      base_url = build_base_url(address, scheme, api_version)

      registry_auth = opts[:registry_auth]

      IO.puts("Base URL: #{base_url}")
      IO.puts("Pulling image: #{image}")

      client = Podman.new(base_url: base_url)

      pull_opts =
        if registry_auth do
          [registry_auth: registry_auth]
        else
          []
        end

      result = Podman.pull_image(client, image, pull_opts)

      CasePrinter.print(result)

      Client.close(client)
    after
      unless opts[:keep_service] do
        stop_service(service_resource)
      end
    end
  end

  defp start_service(podman, "unix") do
    socket_path = Path.join(System.tmp_dir!(), "podman-client-demo-#{unique_id()}.sock")
    File.rm(socket_path)

    args = ["system", "service", "--time=0", "unix:#{socket_path}"]

    %{port: port} = spawn_service(podman, args)
    {socket_path, %{port: port, cleanup: fn -> File.rm(socket_path) end}}
  end

  defp start_service(podman, "tcp") do
    port = random_available_port()
    address = "tcp:127.0.0.1:#{port}"

    %{port: service_port} = spawn_service(podman, ["system", "service", "--time=0", address])
    {port, %{port: service_port, cleanup: fn -> :ok end}}
  end

  defp start_service(_podman, other) do
    raise ArgumentError, "Unsupported scheme #{inspect(other)}. Use \"unix\" or \"tcp\"."
  end

  defp spawn_service(podman, args) do
    port =
      Port.open({:spawn_executable, podman}, [
        :binary,
        :stderr_to_stdout,
        :exit_status,
        :use_stdio,
        {:args, Enum.map(args, &String.to_charlist/1)}
      ])

    %{port: port}
  end

  defp stop_service(%{port: port, cleanup: cleanup}) do
    maybe_kill(port)
    Port.close(port)

    receive do
      {^port, {:exit_status, _}} -> :ok
    after
      1_000 -> :ok
    end

    cleanup.()
  end

  defp maybe_kill(port) do
    case :erlang.port_info(port, :os_pid) do
      {:os_pid, os_pid} when is_integer(os_pid) ->
        _ = System.cmd("kill", ["-TERM", Integer.to_string(os_pid)])
      _ -> :ok
    end
  end

  defp wait_for_service(address, "unix", timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    wait_until(fn -> File.exists?(address) end, deadline, "podman unix socket #{address}")
  end

  defp wait_for_service(port, "tcp", timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout

    wait_until(
      fn ->
        case :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, {:active, false}], 1_000) do
          {:ok, socket} ->
            :gen_tcp.close(socket)
            true

          {:error, _} ->
            false
        end
      end,
      deadline,
      "podman tcp port #{port}"
    )
  end

  defp wait_until(fun, deadline, label) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) > deadline do
        raise "Timed out waiting for #{label}"
      else
        Process.sleep(100)
        wait_until(fun, deadline, label)
      end
    end
  end

  defp detect_api_version(podman) do
    Enum.reduce_while(@api_version_candidates, "5.0.0", fn {command, path}, _acc ->
      case json_value(podman, command, path) do
        {:ok, value} -> {:halt, value}
        :error -> {:cont, "5.0.0"}
      end
    end)
  end

  defp json_value(podman, command, path) do
    case System.cmd(podman, [command, "--format", "{{json .}}"], stderr_to_stdout: true) do
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

  defp build_base_url(address, "unix", api_version) do
    encoded = URI.encode_www_form(address)
    "http+unix://#{encoded}/v#{api_version}/"
  end

  defp build_base_url(port, "tcp", api_version) do
    "http://127.0.0.1:#{port}/v#{api_version}/"
  end

  defp random_available_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, {:active, false}, {:reuseaddr, true}])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  defp unique_id do
    :crypto.strong_rand_bytes(6)
    |> Base.url_encode64(padding: false)
  end
end


defmodule CasePrinter do
  def print({:ok, response}) do
    IO.puts("Pull succeeded. Raw response:")
    IO.puts("-------------------------------")
    IO.inspect(response)
  end

  def print({:error, %Podman.Error{} = error}) do
    IO.puts("Pull failed with Podman.Error")
    IO.puts("--------------------------------")
    IO.puts("Status: #{inspect(error.status)}")
    IO.puts("Message: #{error.message}")

    if error.body do
      IO.puts("Body: #{format_body(error.body)}")
    end
  end

  def print({:error, other}) do
    IO.puts("Pull failed")
    IO.inspect(other)
  end

  defp format_body(body) when is_binary(body), do: body
  defp format_body(body), do: inspect(body)
end

PullDemo.run(System.argv())
