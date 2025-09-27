defmodule Podman.IntegrationCase do
  @moduledoc false

  def random_available_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, {:active, false}, {:reuseaddr, true}])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  def with_tcp_service(podman, fun) when is_function(fun, 1) do
    port = random_available_port()
    address = "tcp:127.0.0.1:#{port}"

    service = start_service!(podman, address)

    try do
      wait_for_tcp(port)
      fun.(port)
    after
      stop_service(service)
    end
  end

  def with_unix_service(podman, fun) when is_function(fun, 1) do
    socket_path = socket_path()
    File.rm(socket_path)
    File.mkdir_p!(Path.dirname(socket_path))

    address = "unix:#{socket_path}"
    service = start_service!(podman, address)

    try do
      wait_for_unix_socket(socket_path)
      fun.(socket_path)
    after
      stop_service(service)
      File.rm(socket_path)
    end
  end

  def unique_name(prefix) do
    suffix =
      :crypto.strong_rand_bytes(6)
      |> Base.url_encode64(padding: false)

    prefix <> "-" <> suffix
  end

  defp socket_path do
    Path.join(System.tmp_dir!(), "podman-client-test-#{unique_name("socket")}.sock")
  end

  defp start_service!(podman, address) do
    port =
      Port.open({:spawn_executable, String.to_charlist(podman)}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        :use_stdio,
        {:args,
         Enum.map(
           [
             "system",
             "service",
             "--time=0",
             "--log-level=error",
             address
           ],
           &String.to_charlist/1
         )}
      ])

    %{port: port, address: address}
  end

  defp stop_service(%{port: port} = service) do
    if os_pid = port_os_pid(port) do
      _ = System.cmd("kill", ["-TERM", Integer.to_string(os_pid)])
    end

    Port.close(port)

    receive do
      {^port, {:exit_status, _status}} -> :ok
    after
      1_000 -> :ok
    end

    service
  end

  defp port_os_pid(port) do
    case :erlang.port_info(port, :os_pid) do
      {:os_pid, pid} when is_integer(pid) -> pid
      _ -> nil
    end
  end

  defp wait_for_tcp(port, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    do_wait(deadline, fn ->
      case :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, {:active, false}], 1_000) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          :ok

        {:error, _} ->
          :retry
      end
    end)
  end

  defp wait_for_unix_socket(path, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    do_wait(deadline, fn ->
      if File.exists?(path) do
        :ok
      else
        :retry
      end
    end)
  end

  defp do_wait(deadline, fun) do
    case fun.() do
      :ok ->
        :ok

      :retry ->
        if System.monotonic_time(:millisecond) >= deadline do
          raise "timeout while waiting for Podman system service"
        else
          Process.sleep(100)
          do_wait(deadline, fun)
        end
    end
  end
end
