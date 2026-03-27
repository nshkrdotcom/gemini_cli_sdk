defmodule GeminiCliSdk.Options do
  @moduledoc """
  Configuration for a Gemini CLI invocation.

  Every field maps to a specific CLI flag, environment variable, or subprocess
  setting. Fields with `nil` default are omitted from the generated argument list.
  """

  alias CliSubprocessCore.ModelInput
  alias GeminiCliSdk.Configuration

  @default_timeout_ms Configuration.default_timeout_ms()

  @type approval_mode :: :default | :auto_edit | :yolo | :plan
  @type resume_value :: boolean() | String.t() | nil

  @type t :: %__MODULE__{
          model_payload: CliSubprocessCore.ModelRegistry.selection() | nil,
          model: String.t() | nil,
          yolo: boolean(),
          approval_mode: approval_mode() | nil,
          sandbox: boolean(),
          resume: resume_value(),
          extensions: [String.t()],
          include_directories: [String.t()],
          allowed_tools: [String.t()],
          allowed_mcp_server_names: [String.t()],
          debug: boolean(),
          output_format: String.t(),
          cwd: String.t() | nil,
          env: map(),
          settings: map() | nil,
          system_prompt: String.t() | nil,
          timeout_ms: pos_integer(),
          max_stderr_buffer_bytes: pos_integer()
        }

  defstruct model_payload: nil,
            model: nil,
            yolo: false,
            approval_mode: nil,
            sandbox: false,
            resume: nil,
            extensions: [],
            include_directories: [],
            allowed_tools: [],
            allowed_mcp_server_names: [],
            debug: false,
            output_format: "stream-json",
            cwd: nil,
            env: %{},
            settings: nil,
            system_prompt: nil,
            timeout_ms: @default_timeout_ms,
            max_stderr_buffer_bytes: Configuration.max_stderr_buffer_size()

  @valid_approval_modes [:default, :auto_edit, :yolo, :plan]

  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = opts) do
    opts = normalize_model_input!(opts)

    cond do
      opts.yolo && opts.approval_mode != nil ->
        raise ArgumentError,
              "Cannot set both :yolo and :approval_mode. " <>
                "Use approval_mode: :yolo instead of yolo: true"

      opts.approval_mode != nil && opts.approval_mode not in @valid_approval_modes ->
        raise ArgumentError,
              "Invalid approval_mode: #{inspect(opts.approval_mode)}. " <>
                "Must be one of: #{inspect(@valid_approval_modes)}"

      length(opts.include_directories) > Configuration.max_include_directories() ->
        raise ArgumentError,
              "Maximum #{Configuration.max_include_directories()} include_directories allowed, got #{length(opts.include_directories)}"

      opts.timeout_ms <= 0 ->
        raise ArgumentError,
              "timeout_ms must be positive, got #{opts.timeout_ms}"

      opts.max_stderr_buffer_bytes <= 0 ->
        raise ArgumentError,
              "max_stderr_buffer_bytes must be positive, got #{opts.max_stderr_buffer_bytes}"

      true ->
        opts
    end
  end

  defp normalize_model_input!(%__MODULE__{} = opts) do
    env_model =
      if explicit_model_payload?(opts) do
        nil
      else
        Map.get(opts.env, "GEMINI_MODEL") ||
          Map.get(opts.env, :GEMINI_MODEL) ||
          System.get_env("GEMINI_MODEL")
      end

    attrs =
      Map.from_struct(opts)
      |> maybe_put_env_model(env_model)

    case ModelInput.normalize(:gemini, attrs) do
      {:ok, normalized} ->
        %{opts | model_payload: normalized.selection, model: normalized.selection.resolved_model}

      {:error, reason} ->
        raise ArgumentError, "model resolution failed for :gemini: #{inspect(reason)}"
    end
  end

  defp maybe_put_env_model(attrs, nil), do: attrs
  defp maybe_put_env_model(attrs, value), do: Map.put(attrs, :env_model, value)

  defp explicit_model_payload?(%__MODULE__{model_payload: payload}) when is_map(payload), do: true
  defp explicit_model_payload?(_opts), do: false
end
