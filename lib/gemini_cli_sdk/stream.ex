defmodule GeminiCliSdk.Stream do
  @moduledoc """
  Lazy streaming execution of Gemini CLI prompts via `Stream.resource/3`.
  """

  alias CliSubprocessCore.Event, as: CoreEvent
  alias GeminiCliSdk.{Configuration, Error, Options, Runtime.CLI, Types}

  @session_close_grace_ms Configuration.transport_close_grace_ms()
  @session_kill_grace_ms Configuration.transport_kill_grace_ms()

  defmodule State do
    @moduledoc false

    @default_receive_timeout_ms GeminiCliSdk.Configuration.stream_timeout_ms()

    @enforce_keys [
      :session,
      :session_ref,
      :session_monitor_ref,
      :session_event_tag,
      :projection_state,
      :receive_timeout_ms
    ]
    defstruct session: nil,
              session_ref: nil,
              session_monitor_ref: nil,
              session_event_tag: nil,
              projection_state: nil,
              done?: false,
              temp_dir: nil,
              stderr: "",
              stderr_truncated?: false,
              receive_timeout_ms: @default_receive_timeout_ms,
              max_stderr_buffer_bytes: GeminiCliSdk.Configuration.max_stderr_buffer_size()

    @type t :: %__MODULE__{
            session: pid(),
            session_ref: reference(),
            session_monitor_ref: reference(),
            session_event_tag: atom(),
            projection_state: map(),
            done?: boolean(),
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
    session_ref = make_ref()

    case CLI.start_session(prompt: prompt, options: options, subscriber: {self(), session_ref}) do
      {:ok, session, %{info: info, projection_state: projection_state, temp_dir: temp_dir}} ->
        init_session(
          session,
          session_ref,
          Map.get(info, :session_event_tag, CLI.session_event_tag()),
          projection_state,
          temp_dir,
          options.timeout_ms,
          options.max_stderr_buffer_bytes
        )

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

  defp init_session(
         session,
         session_ref,
         session_event_tag,
         projection_state,
         temp_dir,
         timeout_ms,
         max_stderr_buffer_bytes
       ) do
    session_monitor_ref = Process.monitor(session)

    case end_input(session) do
      :ok ->
        %State{
          session: session,
          session_ref: session_ref,
          session_monitor_ref: session_monitor_ref,
          session_event_tag: session_event_tag,
          projection_state: projection_state,
          temp_dir: temp_dir,
          receive_timeout_ms: timeout_ms,
          max_stderr_buffer_bytes: max_stderr_buffer_bytes
        }

      {:error, reason} ->
        _ = CLI.close(session)
        cleanup_temp_dir(temp_dir)
        {:error, Error.normalize(reason, kind: :stream_start_failed)}
    end
  end

  defp end_input(session) do
    CLI.end_input(session)
  catch
    :exit, reason -> {:error, {:transport_call_exit, reason}}
  end

  defp receive_next({:error, reason}) do
    {[start_failure_event(reason)], {:halted}}
  end

  defp receive_next({:halted}), do: {:halt, {:halted}}
  defp receive_next(%State{done?: true} = state), do: {:halt, state}

  defp receive_next(%State{} = state) do
    receive do
      {event_tag, ref, {:event, %CoreEvent{} = event}}
      when event_tag == state.session_event_tag and ref == state.session_ref ->
        handle_core_event(event, state)

      {:DOWN, monitor_ref, :process, _pid, _reason}
      when monitor_ref == state.session_monitor_ref ->
        {:halt, mark_done(state)}
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

  defp handle_core_event(event, %State{} = state) do
    state = maybe_capture_stderr(state, event)

    {projected, projection_state} = CLI.project_event(event, state.projection_state)
    state = %{state | projection_state: projection_state}

    projected =
      Enum.map(projected, fn projected_event ->
        maybe_attach_stderr(projected_event, state)
      end)

    case projected do
      [] ->
        receive_next(state)

      events ->
        state =
          if Enum.any?(events, &Types.final_event?/1) do
            mark_done(state)
          else
            state
          end

        {events, state}
    end
  end

  defp maybe_capture_stderr(%State{} = state, %CoreEvent{} = event) do
    case CLI.stderr_chunk(event) do
      chunk when is_binary(chunk) ->
        {stderr, truncated?} =
          append_stderr_tail(
            state.stderr,
            chunk,
            state.max_stderr_buffer_bytes,
            state.stderr_truncated?
          )

        %{state | stderr: stderr, stderr_truncated?: truncated?}

      _other ->
        state
    end
  end

  defp maybe_attach_stderr(%Types.ErrorEvent{severity: "fatal"} = event, %State{} = state) do
    %Types.ErrorEvent{
      event
      | stderr: event.stderr || normalize_stderr(state.stderr),
        stderr_truncated?: state.stderr_truncated?
    }
  end

  defp maybe_attach_stderr(event, _state), do: event

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
  defp normalize_stderr(_stderr), do: ""

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

  defp start_failure_event(reason) do
    error = Error.normalize(reason, kind: :stream_start_failed)

    build_error_event(error.message,
      kind: error.kind,
      details: start_failure_details(error),
      exit_code: error.exit_code,
      stderr: error.details
    )
  end

  defp start_failure_details(%Error{} = error) do
    %{}
    |> maybe_put(:underlying_kind, error.context && error.context[:underlying_kind])
    |> maybe_put(:context, error.context)
    |> maybe_put(:cause, error.cause && inspect(error.cause))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp mark_done(%State{} = state), do: %{state | done?: true}

  defp cleanup(%State{} = state) do
    close_session_with_timeout(state.session, state.session_monitor_ref, @session_close_grace_ms)
    flush_session_messages(state.session_ref, state.session_monitor_ref, state.session_event_tag)
    cleanup_temp_dir(state.temp_dir)
    :ok
  end

  defp cleanup(_state), do: :ok

  defp close_session_with_timeout(session, monitor_ref, timeout_ms)
       when is_pid(session) and is_reference(monitor_ref) do
    _ = CLI.close(session)
    await_down_or_shutdown(monitor_ref, session, timeout_ms)
  end

  defp close_session_with_timeout(_session, _monitor_ref, _timeout_ms), do: :ok

  defp flush_session_messages(ref, monitor_ref, session_event_tag)
       when is_reference(ref) and is_reference(monitor_ref) and is_atom(session_event_tag) do
    receive do
      {event_tag, ^ref, {:event, _event}} when event_tag == session_event_tag ->
        flush_session_messages(ref, monitor_ref, session_event_tag)

      {:DOWN, ^monitor_ref, :process, _pid, _reason} ->
        flush_session_messages(ref, monitor_ref, session_event_tag)
    after
      0 -> :ok
    end
  end

  defp flush_session_messages(_ref, _monitor_ref, _session_event_tag), do: :ok

  defp await_down_or_shutdown(ref, session, timeout_ms) do
    receive do
      {:DOWN, ^ref, :process, _pid, _reason} -> :ok
    after
      timeout_ms ->
        safe_shutdown(session)
        await_down_or_kill(ref, session, @session_kill_grace_ms)
    end
  end

  defp await_down_or_kill(ref, session, timeout_ms) do
    receive do
      {:DOWN, ^ref, :process, _pid, _reason} -> :ok
    after
      timeout_ms ->
        safe_kill(session)
        await_down_or_demonitor(ref, @session_kill_grace_ms)
    end
  end

  defp await_down_or_demonitor(ref, timeout_ms) do
    receive do
      {:DOWN, ^ref, :process, _pid, _reason} -> :ok
    after
      timeout_ms ->
        Process.demonitor(ref, [:flush])
        :ok
    end
  end

  defp safe_shutdown(session) when is_pid(session) do
    Process.exit(session, :shutdown)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp safe_kill(session) when is_pid(session) do
    Process.exit(session, :kill)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp cleanup_temp_dir(nil), do: :ok
  defp cleanup_temp_dir(temp_dir), do: GeminiCliSdk.Config.cleanup(temp_dir)
end
