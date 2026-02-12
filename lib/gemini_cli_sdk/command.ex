defmodule GeminiCliSdk.Command do
  @moduledoc "Synchronous command execution against the Gemini CLI."

  alias GeminiCliSdk.{CLI, Defaults, Env, Error, Exec}
  alias GeminiCliSdk.CLI.CommandSpec

  @stop_wait_ms 200
  @kill_wait_ms 500

  @type run_opt ::
          {:timeout, non_neg_integer() | :infinity}
          | {:stdin, iodata()}
          | {:cd, String.t()}
          | {:env, map() | keyword()}

  @spec run([String.t()], [run_opt()]) :: {:ok, String.t()} | {:error, Error.t()}
  def run(args, opts \\ []) when is_list(args) and is_list(opts) do
    with {:ok, command} <- CLI.resolve() do
      run(command, args, opts)
    end
  end

  @spec run(CommandSpec.t(), [String.t()], [run_opt()]) ::
          {:ok, String.t()} | {:error, Error.t()}
  def run(%CommandSpec{} = command, args, opts) when is_list(args) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, Defaults.command_timeout_ms())

    command_args = CLI.command_args(command, args)
    env = Env.build_cli_env(normalize_env(Keyword.get(opts, :env)))
    cwd = Keyword.get(opts, :cd)
    stdin = Keyword.get(opts, :stdin)

    case run_exec_command(command.program, command_args, env, cwd, stdin, timeout) do
      {:ok, {output, 0}} ->
        {:ok, String.trim(output)}

      {:ok, {output, code}} ->
        stderr_text = String.trim(output)

        {:error,
         Error.new(
           kind: exit_code_to_kind(code),
           message: "CLI exited with code #{code}: #{stderr_text}",
           exit_code: code,
           details: stderr_text
         )}

      {:error, :timeout} ->
        {:error,
         Error.new(
           kind: :command_timeout,
           message: "Command timed out after #{timeout}ms",
           exit_code: 124
         )}

      {:error, reason} ->
        {:error,
         Error.new(
           kind: :command_execution_failed,
           message: "Failed to execute command: #{inspect(reason)}",
           cause: reason
         )}
    end
  end

  defp exit_code_to_kind(41), do: :auth_error
  defp exit_code_to_kind(42), do: :input_error
  defp exit_code_to_kind(52), do: :config_error
  defp exit_code_to_kind(130), do: :user_cancelled
  defp exit_code_to_kind(_), do: :command_failed

  defp run_exec_command(program, args, env, cwd, stdin, timeout) do
    timeout_deadline = timeout_deadline(timeout)

    exec_opts =
      [:stdin, :stdout, :stderr, :monitor]
      |> Exec.add_cwd(cwd)
      |> Exec.add_env(env)

    cmd = Exec.build_command(program, args)

    case :exec.run(cmd, exec_opts) do
      {:ok, pid, os_pid} ->
        case send_stdin(pid, stdin) do
          :ok ->
            collect_output(pid, os_pid, timeout_deadline, [], [])

          {:error, reason} ->
            stop_and_confirm_down(pid, os_pid)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error -> {:error, {:exception, error}}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp send_stdin(pid, nil) do
    send_eof(pid)
  end

  defp send_stdin(pid, stdin) when is_binary(stdin) do
    :ok = :exec.send(pid, stdin)
    send_eof(pid)
  catch
    kind, reason -> {:error, {:send_failed, {kind, reason}}}
  end

  defp send_eof(pid) do
    :ok = :exec.send(pid, :eof)
    :ok
  catch
    kind, reason -> {:error, {:send_failed, {kind, reason}}}
  end

  defp collect_output(pid, os_pid, :infinity, stdout_chunks, stderr_chunks) do
    receive do
      {:stdout, ^os_pid, data} ->
        collect_output(
          pid,
          os_pid,
          :infinity,
          [IO.iodata_to_binary(data) | stdout_chunks],
          stderr_chunks
        )

      {:stderr, ^os_pid, data} ->
        collect_output(pid, os_pid, :infinity, stdout_chunks, [
          IO.iodata_to_binary(data) | stderr_chunks
        ])

      {:DOWN, ^os_pid, :process, ^pid, reason} ->
        exit_code = decode_exit_code(reason)
        output = build_output(stdout_chunks, stderr_chunks)
        flush_messages(pid, os_pid)
        {:ok, {output, exit_code}}
    end
  end

  defp collect_output(pid, os_pid, deadline, stdout_chunks, stderr_chunks) do
    case timeout_remaining(deadline) do
      :expired ->
        stop_and_confirm_down(pid, os_pid)
        {:error, :timeout}

      remaining ->
        receive do
          {:stdout, ^os_pid, data} ->
            collect_output(
              pid,
              os_pid,
              deadline,
              [IO.iodata_to_binary(data) | stdout_chunks],
              stderr_chunks
            )

          {:stderr, ^os_pid, data} ->
            collect_output(pid, os_pid, deadline, stdout_chunks, [
              IO.iodata_to_binary(data) | stderr_chunks
            ])

          {:DOWN, ^os_pid, :process, ^pid, reason} ->
            exit_code = decode_exit_code(reason)
            output = build_output(stdout_chunks, stderr_chunks)
            flush_messages(pid, os_pid)
            {:ok, {output, exit_code}}
        after
          remaining ->
            stop_and_confirm_down(pid, os_pid)
            {:error, :timeout}
        end
    end
  end

  defp build_output(stdout_chunks, stderr_chunks) do
    stdout = stdout_chunks |> Enum.reverse() |> IO.iodata_to_binary()
    stderr = stderr_chunks |> Enum.reverse() |> IO.iodata_to_binary()
    stdout <> stderr
  end

  defp timeout_deadline(:infinity), do: :infinity
  defp timeout_deadline(timeout_ms), do: System.monotonic_time(:millisecond) + timeout_ms

  defp timeout_remaining(deadline_ms) do
    remaining = deadline_ms - System.monotonic_time(:millisecond)
    if remaining <= 0, do: :expired, else: remaining
  end

  defp stop_and_confirm_down(pid, os_pid) do
    stop_exec(pid)

    case await_down(pid, os_pid, @stop_wait_ms) do
      :down ->
        flush_messages(pid, os_pid)

      :timeout ->
        kill_exec(pid)
        _ = await_down(pid, os_pid, @kill_wait_ms)
        flush_messages(pid, os_pid)
    end
  end

  defp await_down(pid, os_pid, timeout_ms) do
    receive do
      {:DOWN, ^os_pid, :process, ^pid, _reason} -> :down
    after
      timeout_ms -> :timeout
    end
  end

  defp flush_messages(pid, os_pid) do
    receive do
      {:stdout, ^os_pid, _data} -> flush_messages(pid, os_pid)
      {:stderr, ^os_pid, _data} -> flush_messages(pid, os_pid)
      {:DOWN, ^os_pid, :process, ^pid, _reason} -> :ok
    after
      0 -> :ok
    end
  end

  defp stop_exec(pid) do
    :exec.stop(pid)
    :ok
  catch
    _, _ -> :ok
  end

  defp kill_exec(pid) do
    :exec.kill(pid, 9)
    :ok
  catch
    _, _ -> :ok
  end

  defp decode_exit_code(:normal), do: 0
  defp decode_exit_code(0), do: 0

  defp decode_exit_code({:exit_status, code}) when is_integer(code),
    do: normalize_exit_status(code)

  defp decode_exit_code({:status, code}) when is_integer(code), do: normalize_exit_status(code)
  defp decode_exit_code(code) when is_integer(code), do: normalize_exit_status(code)
  defp decode_exit_code(_reason), do: 1

  defp normalize_exit_status(code) when code > 255 and rem(code, 256) == 0, do: div(code, 256)
  defp normalize_exit_status(code), do: code

  defp normalize_env(nil), do: %{}
  defp normalize_env(env) when is_map(env) or is_list(env), do: Env.normalize_overrides(env)
end
