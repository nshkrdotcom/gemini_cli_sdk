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
              receive_timeout_ms: @default_receive_timeout_ms

    @type t :: %__MODULE__{
            transport: pid(),
            transport_ref: reference(),
            done?: boolean(),
            received_result?: boolean(),
            temp_dir: String.t() | nil,
            stderr: String.t(),
            receive_timeout_ms: pos_integer()
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
           subscriber: {self(), transport_ref}
         ) do
      {:ok, transport} ->
        init_transport(transport, prompt, transport_ref, temp_dir, options.timeout_ms)

      {:error, reason} ->
        cleanup_temp_dir(temp_dir)
        {:error, Error.normalize(reason, kind: :stream_start_failed)}
    end
  end

  defp init_transport(transport, prompt, transport_ref, temp_dir, timeout_ms) do
    case send_initial_input(transport, prompt) do
      :ok ->
        %State{
          transport: transport,
          transport_ref: transport_ref,
          temp_dir: temp_dir,
          receive_timeout_ms: timeout_ms
        }

      {:error, reason} ->
        cleanup_start_resources(transport, temp_dir)
        {:error, Error.normalize(reason, kind: :stream_start_failed)}
    end
  end

  defp send_initial_input(transport, prompt) do
    with :ok <- Erlexec.send(transport, prompt) do
      Erlexec.end_input(transport)
    end
  catch
    :exit, reason -> {:error, {:transport_call_exit, reason}}
  end

  defp cleanup_start_resources(transport, temp_dir) do
    safe_close(transport)
    cleanup_temp_dir(temp_dir)
  end

  defp receive_next({:error, reason}) do
    error_event = %Types.ErrorEvent{
      severity: "fatal",
      message: "Failed to start: #{Error.message(reason)}"
    }

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

        error_event = %Types.ErrorEvent{
          severity: "fatal",
          message: "Transport error: #{normalized.message}"
        }

        {[error_event], mark_done(state)}

      {:gemini_sdk_transport, ref, {:stderr, data}}
      when ref == state.transport_ref and is_binary(data) ->
        receive_next(append_stderr(state, data))

      {:gemini_sdk_transport, ref, {:exit, reason}} when ref == state.transport_ref ->
        handle_transport_exit(reason, state)
    after
      state.receive_timeout_ms ->
        timeout_event = %Types.ErrorEvent{
          severity: "fatal",
          message: "Timed out after #{state.receive_timeout_ms}ms waiting for CLI output"
        }

        {[timeout_event], mark_done(state)}
    end
  end

  defp handle_transport_exit(_reason, %State{received_result?: true} = state) do
    {:halt, mark_done(state)}
  end

  defp handle_transport_exit(reason, %State{} = state) do
    error_text =
      cond do
        String.trim(state.stderr) != "" ->
          String.trim(state.stderr)

        reason == :normal ->
          "CLI process exited without producing output"

        true ->
          "CLI process exited: #{inspect(reason)}"
      end

    error_event = %Types.ErrorEvent{
      severity: "fatal",
      message: error_text
    }

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
        error_event = %Types.ErrorEvent{
          severity: "fatal",
          message: "JSON parse error: #{reason.message}"
        }

        {[error_event], mark_done(state)}
    end
  end

  defp append_stderr(%State{} = state, data), do: %{state | stderr: state.stderr <> data}
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
