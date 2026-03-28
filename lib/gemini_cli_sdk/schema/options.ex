defmodule GeminiCliSdk.Schema.Options do
  @moduledoc false

  alias CliSubprocessCore.{ExecutionSurface, Schema.Conventions}
  alias GeminiCliSdk.{Configuration, Options, Schema}

  @default_timeout_ms Configuration.default_timeout_ms()
  @default_max_stderr_buffer_bytes Configuration.max_stderr_buffer_size()
  @max_include_directories Configuration.max_include_directories()
  @approval_mode_aliases %{
    :default => :default,
    :auto_edit => :auto_edit,
    :yolo => :yolo,
    :plan => :plan,
    "default" => :default,
    "auto_edit" => :auto_edit,
    "full_auto" => :yolo,
    "plan" => :plan,
    "yolo" => :yolo
  }

  @spec schema() :: Zoi.schema()
  def schema do
    Zoi.map(
      %{
        execution_surface: execution_surface_schema(),
        model_payload: Conventions.optional_any(),
        model: Conventions.optional_trimmed_string(),
        yolo: Zoi.default(Zoi.optional(Zoi.nullish(Zoi.boolean())), false),
        approval_mode: Zoi.optional(Zoi.nullish(approval_mode_schema())),
        sandbox: Zoi.default(Zoi.optional(Zoi.nullish(Zoi.boolean())), false),
        resume: Zoi.optional(Zoi.nullish(resume_schema())),
        extensions: string_list_schema(),
        include_directories: include_directories_schema(),
        allowed_tools: string_list_schema(),
        allowed_mcp_server_names: string_list_schema(),
        debug: Zoi.default(Zoi.optional(Zoi.nullish(Zoi.boolean())), false),
        output_format: output_format_schema(),
        cwd: Conventions.optional_trimmed_string(),
        env: Conventions.default_map(%{}),
        settings: Conventions.optional_map(),
        system_prompt: Conventions.optional_trimmed_string(),
        timeout_ms: positive_integer_schema(:timeout_ms, @default_timeout_ms),
        max_stderr_buffer_bytes:
          positive_integer_schema(:max_stderr_buffer_bytes, @default_max_stderr_buffer_bytes)
      },
      unrecognized_keys: :error
    )
  end

  @spec parse(Options.t() | map()) ::
          {:ok, Options.t()}
          | {:error, {:invalid_options, CliSubprocessCore.Schema.error_detail()}}
  def parse(%Options{} = opts), do: parse(Map.from_struct(opts))

  def parse(attrs) when is_map(attrs) do
    case Schema.parse(schema(), attrs, :invalid_options) do
      {:ok, parsed} ->
        {:ok, project(parsed)}

      {:error, {:invalid_options, details}} ->
        {:error, {:invalid_options, details}}
    end
  end

  @spec parse!(Options.t() | map()) :: Options.t()
  def parse!(%Options{} = opts), do: parse!(Map.from_struct(opts))

  def parse!(attrs) when is_map(attrs) do
    schema()
    |> Schema.parse!(attrs, :invalid_options)
    |> project()
  end

  @doc false
  def normalize_approval_mode(value, opts), do: normalize_approval_mode(value, [], opts)

  @doc false
  def normalize_approval_mode(value, _args, _opts) do
    case normalize_approval_mode_key(value) do
      nil -> {:error, invalid_approval_mode_message(value)}
      key -> {:ok, Map.fetch!(@approval_mode_aliases, key)}
    end
  end

  @doc false
  def normalize_resume(value, opts), do: normalize_resume(value, [], opts)

  @doc false
  def normalize_resume(value, _args, _opts) do
    cond do
      value in [nil, false] ->
        {:ok, nil}

      value == true ->
        {:ok, true}

      is_binary(value) ->
        case String.trim(value) do
          "" -> {:error, "resume must be true or a non-empty session id"}
          trimmed -> {:ok, trimmed}
        end

      true ->
        {:error, "resume must be true or a non-empty session id"}
    end
  end

  @doc false
  def validate_include_directories(value, limit, _opts) when is_list(value) do
    if length(value) > limit do
      {:error, "Maximum #{limit} include_directories allowed, got #{length(value)}"}
    else
      {:ok, value}
    end
  end

  @doc false
  def normalize_positive_integer(value, field, _opts) do
    if is_integer(value) and value > 0 do
      {:ok, value}
    else
      {:error, "#{field} must be positive, got #{inspect(value)}"}
    end
  end

  @doc false
  def normalize_output_format(value, default, _opts) when is_binary(default) do
    case value do
      nil ->
        {:ok, default}

      binary when is_binary(binary) ->
        case String.trim(binary) do
          "" -> {:ok, default}
          trimmed -> {:ok, trimmed}
        end

      other ->
        {:error, "output_format must be a string, got: #{inspect(other)}"}
    end
  end

  defp approval_mode_schema,
    do: Zoi.any() |> Zoi.transform({__MODULE__, :normalize_approval_mode, []})

  @doc false
  def normalize_execution_surface(value, opts), do: normalize_execution_surface(value, [], opts)

  @doc false
  def normalize_execution_surface(value, _args, _opts) do
    case Options.normalize_execution_surface(value) do
      {:ok, execution_surface} ->
        {:ok, execution_surface}

      {:error, {:invalid_execution_surface, other}} ->
        {:error,
         "execution_surface must be a CliSubprocessCore.ExecutionSurface struct, keyword list, or map, got: #{inspect(other)}"}

      {:error, reason} ->
        {:error, "invalid execution_surface: #{inspect(reason)}"}
    end
  end

  defp resume_schema, do: Zoi.any() |> Zoi.transform({__MODULE__, :normalize_resume, []})

  defp execution_surface_schema do
    Zoi.default(
      Zoi.optional(
        Zoi.nullish(
          Zoi.any()
          |> Zoi.transform({__MODULE__, :normalize_execution_surface, []})
        )
      ),
      %ExecutionSurface{}
    )
  end

  defp string_list_schema do
    Zoi.default(
      Zoi.optional(Zoi.nullish(Zoi.array(Conventions.trimmed_string() |> Zoi.min(1)))),
      []
    )
  end

  defp include_directories_schema do
    Zoi.default(
      Zoi.optional(
        Zoi.nullish(
          Zoi.array(Conventions.trimmed_string() |> Zoi.min(1))
          |> Zoi.transform(
            {__MODULE__, :validate_include_directories, [@max_include_directories]}
          )
        )
      ),
      []
    )
  end

  defp positive_integer_schema(field, default) when is_atom(field) and is_integer(default) do
    Zoi.default(
      Zoi.optional(
        Zoi.nullish(
          Zoi.any()
          |> Zoi.transform({__MODULE__, :normalize_positive_integer, [field]})
        )
      ),
      default
    )
  end

  defp output_format_schema do
    Zoi.default(
      Zoi.optional(
        Zoi.nullish(
          Zoi.any()
          |> Zoi.transform({__MODULE__, :normalize_output_format, ["stream-json"]})
        )
      ),
      "stream-json"
    )
  end

  defp project(parsed) do
    %Options{
      execution_surface: Map.get(parsed, :execution_surface, %ExecutionSurface{}),
      model_payload: Map.get(parsed, :model_payload),
      model: blank_to_nil(Map.get(parsed, :model)),
      yolo: Map.get(parsed, :yolo, false),
      approval_mode: Map.get(parsed, :approval_mode),
      sandbox: Map.get(parsed, :sandbox, false),
      resume: Map.get(parsed, :resume),
      extensions: Map.get(parsed, :extensions, []),
      include_directories: Map.get(parsed, :include_directories, []),
      allowed_tools: Map.get(parsed, :allowed_tools, []),
      allowed_mcp_server_names: Map.get(parsed, :allowed_mcp_server_names, []),
      debug: Map.get(parsed, :debug, false),
      output_format: Map.get(parsed, :output_format, "stream-json"),
      cwd: blank_to_nil(Map.get(parsed, :cwd)),
      env: Map.get(parsed, :env, %{}),
      settings: Map.get(parsed, :settings),
      system_prompt: blank_to_nil(Map.get(parsed, :system_prompt)),
      timeout_ms: Map.get(parsed, :timeout_ms, @default_timeout_ms),
      max_stderr_buffer_bytes:
        Map.get(parsed, :max_stderr_buffer_bytes, @default_max_stderr_buffer_bytes)
    }
  end

  defp normalize_approval_mode_key(value) when value in [:default, :auto_edit, :yolo, :plan],
    do: value

  defp normalize_approval_mode_key(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> String.replace("-", "_")
    |> then(fn key -> if Map.has_key?(@approval_mode_aliases, key), do: key, else: nil end)
  end

  defp normalize_approval_mode_key(_value), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(nil), do: nil

  defp invalid_approval_mode_message(value) do
    "Invalid approval_mode: #{inspect(value)}. Must be one of: #{inspect([:default, :auto_edit, :yolo, :plan])}"
  end
end
