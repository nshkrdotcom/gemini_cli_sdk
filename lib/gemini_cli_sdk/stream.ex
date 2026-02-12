defmodule GeminiCliSdk.Stream do
  @moduledoc "Lazy streaming execution of Gemini CLI prompts via `Stream.resource/3`."

  alias GeminiCliSdk.{ArgBuilder, CLI, Config, Configuration, Env, Error, Types}
  alias GeminiCliSdk.Options
  alias GeminiCliSdk.Transport.Erlexec

  @transport_close_grace_ms Configuration.transport_close_grace_ms()
  @transport_kill_grace_ms Configuration.transport_kill_grace_ms()

  defmodule State do
    @moduledoc false
    @default_receive_timeout_ms GeminiCliSdk.Configuration.stream_timeout_ms()

    @enforce_keys [:transport, :transport_ref, :receive_timeout_ms]
    defstruct transport: nil,
              transport_ref: nil,
              done?: false,
              received_result?: false,
              temp_dir: nil,
              stderr: "",
              stderr_truncated?: false,
              receive_timeout_ms: @default_receive_timeout_ms,
              max_stderr_buffer_bytes: GeminiCliSdk.Configuration.max_stderr_buffer_size()

    @type t :: %__MODULE__{
            transport: pid(),
            transport_ref: reference(),
            done?: boolean(),
            received_result?: boolean(),
            temp_dir: String.t() | nil,
            stderr: String.t(),
            stderr_truncated?: boolean(),
            receive_timeout_ms: pos_integer(),
            max_stderr_buffer_bytes: pos_integer()
          }
  end

  @spec execute(String.t(), Options.t()) :: Enumerable.t(Types.stream_event())
  def execute(prompt, %Options{} = options \\ %Options{}) when is_binary(prompt) do
    Stream.resource(
      fn -> start(prompt, options) end,
      &receive_next/1,
      &cleanup/1
    )
  end

  defp start(prompt, %Options{} = options) do
    with {:ok, command} <- CLI.resolve(),
         {:ok, settings_path, temp_dir} <- build_settings_file(options) do
      start_transport(command, prompt, options, settings_path, temp_dir)
    else
      {:error, reason} ->
        {:error, Error.normalize(reason, kind: :stream_start_failed)}
    end
  rescue
    error ->
      {:error, Error.normalize(error, kind: :stream_start_failed)}
  catch
    :exit, reason ->
      {:error, Error.normalize(reason, kind: :stream_start_failed)}
  end

  defp start_transport(command, prompt, options, settings_path, temp_dir) do
    args = build_args(options, prompt, settings_path)
    full_args = CLI.command_args(command, args)
    env = build_env(options)
    cwd = options.cwd || File.cwd!()
    transport_ref = make_ref()

    case Erlexec.start(
           command: command.program,
           args: full_args,
           cwd: cwd,
           env: Enum.to_list(env),
           subscriber: {self(), transport_ref},
           max_stderr_buffer_size: options.max_stderr_buffer_bytes + 1
         ) do
      {:ok, transport} ->
        init_transport(
          transport,
          prompt,
          transport_ref,
          temp_dir,
          options.timeout_ms,
          options.max_stderr_buffer_bytes
        )

      {:error, reason} ->
        cleanup_temp_dir(temp_dir)
        {:error, Error.normalize(reason, kind: :stream_start_failed)}
    end
  end

  defp init_transport(
         transport,
         _prompt,
         transport_ref,
         temp_dir,
         timeout_ms,
         max_stderr_buffer_bytes
       ) do
    case close_stdin(transport) do
      :ok ->
        %State{
          transport: transport,
          transport_ref: transport_ref,
          temp_dir: temp_dir,
          receive_timeout_ms: timeout_ms,
          max_stderr_buffer_bytes: max_stderr_buffer_bytes
        }

      {:error, reason} ->
        cleanup_start_resources(transport, temp_dir)
        {:error, Error.normalize(reason, kind: :stream_start_failed)}
    end
  end

  defp close_stdin(transport) do
    Erlexec.end_input(transport)
  catch
    :exit, reason -> {:error, {:transport_call_exit, reason}}
  end

  defp cleanup_start_resources(transport, temp_dir) do
    safe_close(transport)
    cleanup_temp_dir(temp_dir)
  end

  defp receive_next({:error, reason}) do
    error_event =
      build_error_event("Failed to start: #{Error.message(reason)}",
        kind: :stream_start_failed,
        details: %{
          cause: inspect(reason)
        }
      )

    {[error_event], {:halted}}
  end

  defp receive_next({:halted}), do: {:halt, {:halted}}
  defp receive_next(%State{done?: true} = state), do: {:halt, state}

  defp receive_next(%State{} = state) do
    receive do
      {:gemini_sdk_transport, ref, {:message, line}}
      when ref == state.transport_ref and is_binary(line) ->
        handle_line(line, state)

      {:gemini_sdk_transport, ref, {:error, error}} when ref == state.transport_ref ->
        normalized = Error.normalize(error, kind: :transport_error)

        error_event =
          build_error_event("Transport error: #{normalized.message}",
            kind: :transport_error,
            details: %{
              cause: inspect(normalized.cause),
              context: normalized.context
            },
            stderr: normalize_stderr(state.stderr),
            stderr_truncated?: state.stderr_truncated?
          )

        {[error_event], mark_done(state)}

      {:gemini_sdk_transport, ref, {:stderr, data}}
      when ref == state.transport_ref and is_binary(data) ->
        receive_next(append_stderr(state, data))

      {:gemini_sdk_transport, ref, {:exit, reason}} when ref == state.transport_ref ->
        handle_transport_exit(reason, state)
    after
      state.receive_timeout_ms ->
        timeout_event =
          build_error_event(
            "Timed out after #{state.receive_timeout_ms}ms waiting for CLI output",
            kind: :stream_timeout,
            details: %{
              timeout_ms: state.receive_timeout_ms
            },
            stderr: normalize_stderr(state.stderr),
            stderr_truncated?: state.stderr_truncated?
          )

        {[timeout_event], mark_done(state)}
    end
  end

  defp handle_transport_exit(_reason, %State{received_result?: true} = state) do
    {:halt, mark_done(state)}
  end

  defp handle_transport_exit(reason, %State{} = state) do
    exit_code = decode_exit_code(reason)
    stderr = normalize_stderr(state.stderr)

    error_text =
      cond do
        stderr != "" and is_integer(exit_code) ->
          "CLI exited with code #{exit_code}"

        stderr != "" ->
          "CLI exited with an error"

        is_integer(exit_code) ->
          "CLI exited with code #{exit_code}"

        reason == :normal ->
          "CLI process exited without producing output"

        true ->
          "CLI process exited: #{inspect(reason)}"
      end

    error_event =
      build_error_event(error_text,
        kind: :transport_exit,
        details: %{
          reason: inspect(reason)
        },
        exit_code: exit_code,
        stderr: stderr,
        stderr_truncated?: state.stderr_truncated?
      )

    {[error_event], mark_done(state)}
  end

  defp handle_line(line, %State{} = state) do
    case Types.parse_event(line) do
      {:ok, event} ->
        state =
          if Types.final_event?(event),
            do: mark_result_received(state),
            else: state

        {[event], state}

      {:error, reason} ->
        error_event =
          build_error_event("JSON parse error: #{reason.message}",
            kind: :parse_error,
            details: %{
              cause: inspect(reason.cause)
            },
            stderr: normalize_stderr(state.stderr),
            stderr_truncated?: state.stderr_truncated?
          )

        {[error_event], mark_done(state)}
    end
  end

  defp append_stderr(%State{} = state, data) do
    {stderr, truncated?} =
      append_stderr_tail(
        state.stderr,
        data,
        state.max_stderr_buffer_bytes,
        state.stderr_truncated?
      )

    %{state | stderr: stderr, stderr_truncated?: truncated?}
  end

  defp append_stderr_tail(_existing, _data, max_size, _already_truncated?)
       when not is_integer(max_size) or max_size <= 0,
       do: {"", true}

  defp append_stderr_tail(existing, data, max_size, already_truncated?) do
    combined = existing <> data
    combined_size = byte_size(combined)

    if combined_size <= max_size do
      {combined, already_truncated?}
    else
      {:binary.part(combined, combined_size - max_size, max_size), true}
    end
  end

  defp normalize_stderr(stderr) when is_binary(stderr), do: String.trim(stderr)
  defp normalize_stderr(_), do: ""

  defp decode_exit_code(:normal), do: 0
  defp decode_exit_code(0), do: 0

  defp decode_exit_code({:exit_status, code}) when is_integer(code),
    do: normalize_exit_status(code)

  defp decode_exit_code({:status, code}) when is_integer(code), do: normalize_exit_status(code)
  defp decode_exit_code(code) when is_integer(code), do: normalize_exit_status(code)
  defp decode_exit_code(_reason), do: nil

  defp normalize_exit_status(code) when code > 255 and rem(code, 256) == 0, do: div(code, 256)
  defp normalize_exit_status(code), do: code

  defp build_error_event(message, opts) do
    %Types.ErrorEvent{
      severity: "fatal",
      message: message,
      kind: Keyword.get(opts, :kind),
      details: Keyword.get(opts, :details),
      exit_code: Keyword.get(opts, :exit_code),
      stderr: Keyword.get(opts, :stderr),
      stderr_truncated?: Keyword.get(opts, :stderr_truncated?)
    }
  end

  defp mark_done(%State{} = state), do: %{state | done?: true}

  defp mark_result_received(%State{} = state),
    do: %{state | received_result?: true, done?: true}

  defp cleanup(%State{transport: transport, temp_dir: temp_dir, transport_ref: ref}) do
    close_transport_with_timeout(transport, @transport_close_grace_ms)
    flush_transport_messages(ref)
    cleanup_temp_dir(temp_dir)
    :ok
  end

  defp cleanup(_), do: :ok

  defp close_transport_with_timeout(transport, timeout_ms) when is_pid(transport) do
    ref = Process.monitor(transport)
    _ = safe_force_close(transport)
    await_down_or_shutdown(ref, transport, timeout_ms)
  end

  defp close_transport_with_timeout(_, _), do: :ok

  defp flush_transport_messages(ref) when is_reference(ref) do
    receive do
      {:gemini_sdk_transport, ^ref, _event} ->
        flush_transport_messages(ref)
    after
      0 -> :ok
    end
  end

  defp flush_transport_messages(_), do: :ok

  defp await_down_or_shutdown(ref, transport, timeout_ms) do
    receive do
      {:DOWN, ^ref, :process, _, _} -> :ok
    after
      timeout_ms ->
        safe_shutdown(transport)
        await_down_or_kill(ref, transport, @transport_kill_grace_ms)
    end
  end

  defp await_down_or_kill(ref, transport, timeout_ms) do
    receive do
      {:DOWN, ^ref, :process, _, _} -> :ok
    after
      timeout_ms ->
        safe_kill(transport)
        await_down_or_demonitor(ref, @transport_kill_grace_ms)
    end
  end

  defp await_down_or_demonitor(ref, timeout_ms) do
    receive do
      {:DOWN, ^ref, :process, _, _} -> :ok
    after
      timeout_ms ->
        Process.demonitor(ref, [:flush])
        :ok
    end
  end

  defp safe_close(transport) when is_pid(transport) do
    Erlexec.close(transport)
  catch
    :exit, _ -> :ok
  end

  defp safe_force_close(transport) when is_pid(transport) do
    Erlexec.force_close(transport)
  catch
    :exit, _ -> {:error, {:transport, :not_connected}}
  end

  defp safe_shutdown(transport) when is_pid(transport) do
    Process.exit(transport, :shutdown)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp safe_kill(transport) when is_pid(transport) do
    Process.exit(transport, :kill)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp cleanup_temp_dir(nil), do: :ok

  defp cleanup_temp_dir(dir) do
    File.rm_rf(dir)
  rescue
    _ -> :ok
  end

  defp build_args(options, prompt, settings_path) do
    args = ArgBuilder.build_args(options, prompt)
    maybe_add_settings(args, settings_path)
  end

  defp build_settings_file(%Options{settings: nil}), do: {:ok, nil, nil}

  defp build_settings_file(%Options{settings: settings}) do
    Config.build_settings_file(settings)
  end

  defp maybe_add_settings(args, nil), do: args
  defp maybe_add_settings(args, path), do: args ++ ["--settings-file", path]

  defp build_env(%Options{env: env, system_prompt: system_prompt}) do
    base = Env.build_cli_env(env)

    if system_prompt do
      Map.put(base, "GEMINI_SYSTEM_MD", system_prompt)
    else
      base
    end
  end
end
