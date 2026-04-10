defmodule GeminiCliSdk.Runtime.CLI do
  @moduledoc """
  Session-oriented runtime kit for the shared Gemini CLI lane.

  The tagged mailbox event atom is adapter detail. Higher-level callers should
  consume `GeminiCliSdk.Stream` or projected `GeminiCliSdk.Types.*` events
  instead of treating the underlying session tag as core identity.
  """

  alias CliSubprocessCore.CommandSpec
  alias CliSubprocessCore.Event, as: CoreEvent
  alias CliSubprocessCore.ExecutionSurface
  alias CliSubprocessCore.Payload
  alias CliSubprocessCore.ProviderProfiles.Gemini, as: CoreGemini
  alias CliSubprocessCore.Session
  alias ExecutionPlane.Process.Transport.Error, as: CoreTransportError
  alias ExecutionPlane.ProcessExit, as: CoreProcessExit
  alias GeminiCliSdk.{ArgBuilder, Config, Env, Options, Types}
  alias GeminiCliSdk.CLI, as: GeminiCLI

  @runtime_metadata %{lane: :gemini_cli_sdk}
  @default_session_event_tag :gemini_cli_sdk_runtime_cli
  @session_control_capabilities [
    :session_history,
    :session_resume,
    :session_pause,
    :session_intervene
  ]

  defmodule ProjectionState do
    @moduledoc false

    defstruct result_received?: false

    @type t :: %__MODULE__{result_received?: boolean()}
  end

  defmodule Profile do
    @moduledoc false

    @behaviour CliSubprocessCore.ProviderProfile

    alias CliSubprocessCore.ProviderProfiles.Gemini, as: CoreGemini
    alias GeminiCliSdk.Runtime.CLI

    @impl true
    def id, do: :gemini

    @impl true
    def capabilities, do: CoreGemini.capabilities()

    @impl true
    def build_invocation(opts) when is_list(opts), do: CLI.build_invocation(opts)

    @impl true
    def init_parser_state(opts), do: CoreGemini.init_parser_state(opts)

    @impl true
    def decode_stdout(line, state), do: CoreGemini.decode_stdout(line, state)

    @impl true
    def decode_stderr(chunk, state), do: CoreGemini.decode_stderr(chunk, state)

    @impl true
    def handle_exit(reason, state), do: CoreGemini.handle_exit(reason, state)

    @impl true
    def transport_options(opts), do: CoreGemini.transport_options(opts)
  end

  @type start_option ::
          {:prompt, String.t()}
          | {:options, Options.t()}
          | {:execution_surface, CliSubprocessCore.ExecutionSurface.t() | map() | keyword()}
          | {:subscriber, pid() | {pid(), reference() | :legacy}}
          | {:metadata, map()}
          | {:session_event_tag, atom()}

  @spec start_session([start_option()]) ::
          {:ok, pid(), %{info: map(), projection_state: map(), temp_dir: String.t() | nil}}
          | {:error, term()}
  def start_session(opts) when is_list(opts) do
    prompt = Keyword.get(opts, :prompt, "")

    options =
      opts
      |> Keyword.get(:options, %Options{})
      |> maybe_override_execution_surface(Keyword.get(opts, :execution_surface))
      |> Options.validate!()

    with {:ok, %CommandSpec{} = command_spec} <- GeminiCLI.resolve(options.execution_surface),
         {:ok, settings_path, temp_dir} <- Config.build_settings_file(options.settings) do
      session_opts =
        build_session_options(
          prompt,
          options,
          command_spec,
          settings_path,
          Keyword.take(opts, [:subscriber, :metadata, :session_event_tag])
        )

      case Session.start_session(session_opts) do
        {:ok, session, info} ->
          {:ok, session,
           %{
             info: info,
             projection_state: new_projection_state(),
             temp_dir: temp_dir
           }}

        {:error, reason} ->
          cleanup_temp_dir(temp_dir)
          {:error, reason}
      end
    end
  rescue
    error in [ArgumentError] ->
      {:error, error}
  catch
    :exit, reason ->
      {:error, reason}
  end

  @spec subscribe(pid(), pid(), reference()) :: :ok | {:error, term()}
  def subscribe(session, pid, ref) when is_pid(session) and is_pid(pid) and is_reference(ref) do
    Session.subscribe(session, pid, ref)
  end

  @spec send_input(pid(), iodata(), keyword()) :: :ok | {:error, term()}
  def send_input(session, input, opts \\ []) when is_pid(session) do
    Session.send_input(session, input, opts)
  end

  @spec end_input(pid()) :: :ok | {:error, term()}
  def end_input(session) when is_pid(session), do: Session.end_input(session)

  @spec interrupt(pid()) :: :ok | {:error, term()}
  def interrupt(session) when is_pid(session), do: Session.interrupt(session)

  @spec close(pid()) :: :ok
  def close(session) when is_pid(session), do: Session.close(session)

  @spec info(pid()) :: map()
  def info(session) when is_pid(session), do: Session.info(session)

  @spec capabilities() :: [atom()]
  def capabilities do
    (CoreGemini.capabilities() ++ @session_control_capabilities)
    |> Enum.uniq()
  end

  @spec list_provider_sessions(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_provider_sessions(opts \\ []) when is_list(opts) do
    with {:ok, sessions} <- GeminiCliSdk.list_session_entries(opts) do
      {:ok,
       Enum.map(sessions, fn session ->
         %{
           id: session.id,
           label: session.label,
           cwd: nil,
           updated_at: nil,
           source_kind: :cli_history,
           metadata: %{index: session.index},
           raw: Map.from_struct(session)
         }
       end)}
    end
  end

  @doc false
  @spec session_event_tag() :: atom()
  def session_event_tag, do: @default_session_event_tag

  @spec new_projection_state() :: map()
  def new_projection_state, do: %ProjectionState{}

  @spec project_event(CoreEvent.t(), map()) ::
          {[Types.stream_event()], map()}
  def project_event(%CoreEvent{kind: :run_started}, %ProjectionState{} = state), do: {[], state}
  def project_event(%CoreEvent{kind: :stderr}, %ProjectionState{} = state), do: {[], state}

  def project_event(
        %CoreEvent{kind: :error, payload: %Payload.Error{} = payload, raw: raw},
        %ProjectionState{} = state
      ) do
    project_core_runtime_event(raw, payload, state)
  end

  def project_event(
        %CoreEvent{kind: :result, raw: %{exit: %CoreProcessExit{} = exit}},
        %ProjectionState{} = state
      ) do
    if state.result_received? do
      {[], state}
    else
      event =
        %Types.ErrorEvent{
          severity: "fatal",
          message: exit_message(exit),
          kind: :transport_exit,
          exit_code: exit.code,
          details: %{reason: inspect(exit.reason)}
        }

      {[event], track_event(state, event)}
    end
  end

  def project_event(%CoreEvent{raw: raw}, %ProjectionState{} = state) when is_map(raw) do
    case decode_public_raw(raw) do
      {:ok, event} ->
        {[event], track_event(state, event)}

      :drop ->
        project_core_runtime_event(raw, nil, state)
    end
  end

  def project_event(_event, %ProjectionState{} = state), do: {[], state}

  @spec stderr_chunk(CoreEvent.t()) :: String.t() | nil
  def stderr_chunk(%CoreEvent{kind: :stderr, payload: %Payload.Stderr{content: content}})
      when is_binary(content),
      do: content

  def stderr_chunk(_event), do: nil

  @spec build_invocation(keyword()) :: {:ok, CliSubprocessCore.Command.t()} | {:error, term()}
  def build_invocation(opts) when is_list(opts) do
    prompt = Keyword.get(opts, :prompt, "")

    with true <- is_binary(prompt) || {:error, {:missing_option, :prompt}},
         %CommandSpec{} = command_spec <- Keyword.get(opts, :command_spec),
         true <- is_binary(command_spec.program) || {:error, {:missing_option, :command_spec}} do
      options = options_from_provider_opts(opts)

      args =
        options
        |> ArgBuilder.build_args(prompt)
        |> maybe_add_settings(Keyword.get(opts, :settings_path))

      {:ok,
       CliSubprocessCore.Command.new(
         command_spec,
         args,
         cwd: default_cwd(Keyword.get(opts, :cwd), Keyword.get(opts, :execution_surface)),
         env: Keyword.get(opts, :env, %{})
       )}
    else
      {:error, _reason} = error ->
        error

      _other ->
        {:error, {:missing_option, :command_spec}}
    end
  end

  defp build_session_options(
         prompt,
         %Options{} = options,
         %CommandSpec{} = command_spec,
         settings_path,
         runtime_opts
       ) do
    metadata =
      @runtime_metadata
      |> Map.merge(Keyword.get(runtime_opts, :metadata, %{}))

    [
      provider: :gemini,
      profile: Profile,
      subscriber: Keyword.get(runtime_opts, :subscriber),
      metadata: metadata,
      session_event_tag:
        Keyword.get(runtime_opts, :session_event_tag, @default_session_event_tag),
      prompt: prompt,
      command_spec: command_spec,
      output_format: options.output_format,
      model_payload: options.model_payload,
      model: options.model,
      yolo: options.yolo,
      approval_mode: options.approval_mode,
      sandbox: options.sandbox,
      resume: options.resume,
      extensions: options.extensions,
      include_directories: options.include_directories,
      allowed_tools: options.allowed_tools,
      allowed_mcp_server_names: options.allowed_mcp_server_names,
      debug: options.debug,
      settings_path: settings_path,
      cwd: default_cwd(options.cwd, options.execution_surface),
      env: build_env(options),
      headless_timeout_ms: :infinity,
      max_stderr_buffer_size: options.max_stderr_buffer_bytes
    ] ++ Options.execution_surface_options(options)
  end

  defp options_from_provider_opts(opts) do
    %Options{
      model_payload: Keyword.get(opts, :model_payload),
      model: Keyword.get(opts, :model),
      yolo: Keyword.get(opts, :yolo, false),
      approval_mode: Keyword.get(opts, :approval_mode),
      sandbox: Keyword.get(opts, :sandbox, false),
      resume: Keyword.get(opts, :resume),
      extensions: Keyword.get(opts, :extensions, []),
      include_directories: Keyword.get(opts, :include_directories, []),
      allowed_tools: Keyword.get(opts, :allowed_tools, []),
      allowed_mcp_server_names: Keyword.get(opts, :allowed_mcp_server_names, []),
      debug: Keyword.get(opts, :debug, false),
      output_format: Keyword.get(opts, :output_format, "stream-json")
    }
  end

  defp maybe_add_settings(args, nil), do: args
  defp maybe_add_settings(args, path), do: args ++ ["--settings-file", path]

  defp build_env(%Options{env: env, system_prompt: nil}), do: Env.build_cli_env(env)

  defp build_env(%Options{env: env, system_prompt: system_prompt}) do
    env
    |> Env.build_cli_env()
    |> Map.put("GEMINI_SYSTEM_MD", system_prompt)
  end

  defp maybe_override_execution_surface(%Options{} = options, nil), do: options

  defp maybe_override_execution_surface(%Options{} = options, execution_surface) do
    %{options | execution_surface: execution_surface}
  end

  defp default_cwd(cwd, _execution_surface) when is_binary(cwd) and cwd != "", do: cwd

  defp default_cwd(_cwd, execution_surface) do
    if ExecutionSurface.nonlocal_path_surface?(execution_surface), do: nil, else: File.cwd!()
  end

  defp decode_public_raw(raw) do
    map = stringify_keys(raw)

    case Map.get(map, "type") do
      "init" -> {:ok, Types.InitEvent.from_map(map)}
      "message" -> {:ok, Types.MessageEvent.from_map(map)}
      "tool_use" -> {:ok, Types.ToolUseEvent.from_map(map)}
      "tool_result" -> {:ok, Types.ToolResultEvent.from_map(map)}
      "error" -> {:ok, Types.ErrorEvent.from_map(map)}
      "result" -> {:ok, Types.ResultEvent.from_map(map)}
      _other -> :drop
    end
  end

  defp project_core_runtime_event(
         %{exit: %CoreProcessExit{} = exit},
         %Payload.Error{} = payload,
         state
       ) do
    runtime_failure = payload_runtime_failure(payload)

    event =
      %Types.ErrorEvent{
        severity: "fatal",
        message: payload.message || exit_message(exit),
        kind: normalize_kind(payload.code) || :transport_exit,
        exit_code: runtime_failure_exit_code(runtime_failure, exit),
        details:
          payload.metadata
          |> stringify_keys()
          |> Map.put_new("reason", inspect(exit.reason))
          |> Map.put_new("exit_code", exit.code)
      }

    {[event], track_event(state, event)}
  end

  defp project_core_runtime_event(
         %CoreTransportError{} = error,
         %Payload.Error{} = payload,
         state
       ) do
    event =
      %Types.ErrorEvent{
        severity: "fatal",
        message: "Transport error: #{payload.message}",
        kind: :transport_error,
        details: %{cause: inspect(error.reason), context: error.context}
      }

    {[event], track_event(state, event)}
  end

  defp project_core_runtime_event(_raw, %Payload.Error{code: "parse_error"} = payload, state) do
    line = Map.get(payload.metadata, :line) || Map.get(payload.metadata, "line")

    event =
      %Types.ErrorEvent{
        severity: "fatal",
        message: "JSON parse error: #{payload.message}",
        kind: :parse_error,
        details: %{cause: inspect(line)}
      }

    {[event], track_event(state, event)}
  end

  defp project_core_runtime_event(_raw, %Payload.Error{} = payload, state) do
    event =
      %Types.ErrorEvent{
        severity: "fatal",
        message: payload.message,
        kind: normalize_kind(payload.code),
        details: stringify_keys(payload.metadata)
      }

    {[event], track_event(state, event)}
  end

  defp project_core_runtime_event(_raw, _payload, state), do: {[], state}

  defp track_event(%ProjectionState{} = state, event) do
    if Types.final_event?(event) do
      %{state | result_received?: true}
    else
      state
    end
  end

  defp payload_runtime_failure(%Payload.Error{metadata: metadata}) when is_map(metadata) do
    Map.get(metadata, :runtime_failure) || Map.get(metadata, "runtime_failure") || %{}
  end

  defp payload_runtime_failure(_payload), do: %{}

  defp runtime_failure_exit_code(runtime_failure, %CoreProcessExit{} = exit)
       when is_map(runtime_failure) do
    runtime_failure["exit_code"] || runtime_failure[:exit_code] || exit.code
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) or is_binary(key) -> {to_string(key), value}
      {key, value} -> {inspect(key), value}
    end)
  end

  defp normalize_kind(nil), do: nil
  defp normalize_kind(:unknown), do: nil
  defp normalize_kind(kind) when is_atom(kind), do: kind

  defp normalize_kind("unknown"), do: nil

  defp normalize_kind(kind) when is_binary(kind) do
    kind
    |> String.downcase()
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  defp exit_message(%CoreProcessExit{code: code}) when is_integer(code),
    do: "CLI exited with code #{code}"

  defp exit_message(%CoreProcessExit{status: :signal, signal: signal}) do
    "CLI terminated by signal #{inspect(signal)}"
  end

  defp exit_message(%CoreProcessExit{reason: reason}),
    do: "CLI process exited: #{inspect(reason)}"

  defp cleanup_temp_dir(nil), do: :ok
  defp cleanup_temp_dir(temp_dir), do: Config.cleanup(temp_dir)
end
