defmodule GeminiCliSdk.Options do
  @moduledoc """
  Configuration for a Gemini CLI invocation.

  Every field maps to a specific CLI flag, environment variable, or subprocess
  setting. Fields with `nil` default are omitted from the generated argument list.
  """

  alias GeminiCliSdk.Configuration

  @default_timeout_ms Configuration.default_timeout_ms()

  @type approval_mode :: :default | :auto_edit | :yolo | :plan
  @type resume_value :: boolean() | String.t() | nil

  @type t :: %__MODULE__{
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
          timeout_ms: pos_integer()
        }

  defstruct model: nil,
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
            timeout_ms: @default_timeout_ms

  @valid_approval_modes [:default, :auto_edit, :yolo, :plan]

  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = opts) do
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

      true ->
        opts
    end
  end
end
