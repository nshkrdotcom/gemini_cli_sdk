defmodule GeminiCliSdk.Options do
  @moduledoc """
  Configuration for a Gemini CLI invocation.

  Every field maps to a specific CLI flag or subprocess setting. Fields with
  `nil` default are omitted from the generated argument list.
  """

  alias CliSubprocessCore.{ExecutionSurface, ModelInput}
  alias GeminiCliSdk.Configuration
  alias GeminiCliSdk.Schema.Options, as: OptionsSchema

  @default_timeout_ms Configuration.default_timeout_ms()

  @type approval_mode :: :default | :auto_edit | :yolo | :plan
  @type resume_value :: true | String.t() | nil

  @type t :: %__MODULE__{
          execution_surface: ExecutionSurface.t(),
          model_payload: CliSubprocessCore.ModelRegistry.selection() | nil,
          model: String.t() | nil,
          cli_command: String.t() | nil,
          yolo: boolean(),
          approval_mode: approval_mode() | nil,
          sandbox: boolean(),
          skip_trust: boolean(),
          resume: resume_value(),
          extensions: [String.t()],
          include_directories: [String.t()],
          allowed_tools: [String.t()],
          allowed_mcp_server_names: [String.t()],
          debug: boolean(),
          output_format: String.t(),
          cwd: String.t() | nil,
          settings: map() | nil,
          system_prompt: String.t() | nil,
          timeout_ms: pos_integer(),
          max_stderr_buffer_bytes: pos_integer()
        }

  defstruct execution_surface: %ExecutionSurface{},
            model_payload: nil,
            model: nil,
            cli_command: nil,
            yolo: false,
            approval_mode: nil,
            sandbox: false,
            skip_trust: false,
            resume: nil,
            extensions: [],
            include_directories: [],
            allowed_tools: [],
            allowed_mcp_server_names: [],
            debug: false,
            output_format: "stream-json",
            cwd: nil,
            settings: nil,
            system_prompt: nil,
            timeout_ms: @default_timeout_ms,
            max_stderr_buffer_bytes: Configuration.max_stderr_buffer_size()

  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = opts) do
    case OptionsSchema.parse(opts) do
      {:ok, parsed} ->
        parsed
        |> validate_cross_field_conflicts!()
        |> normalize_model_input!()

      {:error, {:invalid_options, details}} ->
        raise ArgumentError, validation_message(details)
    end
  end

  defp validate_cross_field_conflicts!(%__MODULE__{} = opts) do
    if opts.yolo && opts.approval_mode != nil do
      raise ArgumentError,
            "Cannot set both :yolo and :approval_mode. " <>
              "Use approval_mode: :yolo instead of yolo: true"
    else
      opts
    end
  end

  defp validation_message(%{issues: [%{path: path} | _rest], message: message})
       when is_list(path) and path != [] do
    path_label = Enum.map_join(path, ".", &to_string/1)

    "#{path_label}: #{message}"
  end

  defp validation_message(%{message: message}), do: message

  defp normalize_model_input!(%__MODULE__{} = opts) do
    case ModelInput.normalize(:gemini, Map.from_struct(opts)) do
      {:ok, normalized} ->
        %{opts | model_payload: normalized.selection, model: normalized.selection.resolved_model}

      {:error, reason} ->
        raise ArgumentError, "model resolution failed for :gemini: #{inspect(reason)}"
    end
  end

  @doc false
  @spec normalize_execution_surface(term()) :: {:ok, ExecutionSurface.t()} | {:error, term()}
  def normalize_execution_surface(nil), do: {:ok, %ExecutionSurface{}}

  def normalize_execution_surface(%ExecutionSurface{} = execution_surface),
    do: {:ok, execution_surface}

  def normalize_execution_surface(execution_surface) when is_list(execution_surface) do
    ExecutionSurface.new(execution_surface)
  end

  def normalize_execution_surface(%{} = execution_surface) do
    execution_surface
    |> execution_surface_attrs()
    |> ExecutionSurface.new()
  end

  def normalize_execution_surface(other), do: {:error, {:invalid_execution_surface, other}}

  @doc false
  @spec execution_surface_options(t() | ExecutionSurface.t() | nil) :: keyword()
  def execution_surface_options(%__MODULE__{execution_surface: execution_surface}) do
    execution_surface_options(execution_surface)
  end

  def execution_surface_options(%ExecutionSurface{} = execution_surface) do
    execution_surface
    |> ExecutionSurface.surface_metadata()
    |> Keyword.put(:transport_options, execution_surface.transport_options)
  end

  def execution_surface_options(nil), do: []

  defp execution_surface_attrs(attrs) when is_map(attrs) do
    [
      surface_kind: Map.get(attrs, :surface_kind, Map.get(attrs, "surface_kind")),
      transport_options: Map.get(attrs, :transport_options, Map.get(attrs, "transport_options")),
      target_id: Map.get(attrs, :target_id, Map.get(attrs, "target_id")),
      lease_ref: Map.get(attrs, :lease_ref, Map.get(attrs, "lease_ref")),
      surface_ref: Map.get(attrs, :surface_ref, Map.get(attrs, "surface_ref")),
      boundary_class: Map.get(attrs, :boundary_class, Map.get(attrs, "boundary_class")),
      observability: Map.get(attrs, :observability, Map.get(attrs, "observability", %{}))
    ]
  end
end
