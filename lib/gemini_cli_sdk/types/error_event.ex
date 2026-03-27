defmodule GeminiCliSdk.Types.ErrorEvent do
  @moduledoc "A non-fatal error or warning event."

  alias CliSubprocessCore.Schema.Conventions
  alias GeminiCliSdk.Schema

  @known_fields [
    "type",
    "timestamp",
    "severity",
    "message",
    "kind",
    "details",
    "exit_code",
    "stderr",
    "stderr_truncated"
  ]
  @schema Zoi.map(
            %{
              "type" => Zoi.default(Conventions.optional_trimmed_string(), "error"),
              "timestamp" => Conventions.optional_trimmed_string(),
              "severity" => Zoi.default(Conventions.optional_trimmed_string(), "error"),
              "message" => Zoi.default(Conventions.optional_trimmed_string(), ""),
              "kind" => Conventions.optional_any(),
              "details" => Conventions.optional_map(),
              "exit_code" => Zoi.optional(Zoi.nullish(Zoi.integer())),
              "stderr" => Conventions.optional_trimmed_string(),
              "stderr_truncated" => Zoi.optional(Zoi.nullish(Zoi.boolean()))
            },
            unrecognized_keys: :preserve
          )

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          severity: String.t(),
          message: String.t(),
          kind: atom() | String.t() | nil,
          details: map() | nil,
          exit_code: integer() | nil,
          stderr: String.t() | nil,
          stderr_truncated?: boolean() | nil,
          extra: map()
        }

  defstruct type: "error",
            timestamp: nil,
            severity: "error",
            message: "",
            kind: nil,
            details: nil,
            exit_code: nil,
            stderr: nil,
            stderr_truncated?: nil,
            extra: %{}

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec parse(map() | t()) ::
          {:ok, t()} | {:error, {:invalid_error_event, CliSubprocessCore.Schema.error_detail()}}
  def parse(%__MODULE__{} = event), do: {:ok, event}

  def parse(map) when is_map(map) do
    case Schema.parse(@schema, map, :invalid_error_event) do
      {:ok, parsed} ->
        {known, extra} = Schema.split_extra(parsed, @known_fields)

        {:ok,
         %__MODULE__{
           type: Map.get(known, "type", "error"),
           timestamp: Map.get(known, "timestamp"),
           severity: Map.get(known, "severity", "error"),
           message: Map.get(known, "message", ""),
           kind: Map.get(known, "kind"),
           details: Map.get(known, "details"),
           exit_code: Map.get(known, "exit_code"),
           stderr: Map.get(known, "stderr"),
           stderr_truncated?: Map.get(known, "stderr_truncated"),
           extra: extra
         }}

      {:error, {:invalid_error_event, details}} ->
        {:error, {:invalid_error_event, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = event), do: event

  def parse!(map) when is_map(map) do
    parsed = Schema.parse!(@schema, map, :invalid_error_event)
    {known, extra} = Schema.split_extra(parsed, @known_fields)

    %__MODULE__{
      type: Map.get(known, "type", "error"),
      timestamp: Map.get(known, "timestamp"),
      severity: Map.get(known, "severity", "error"),
      message: Map.get(known, "message", ""),
      kind: Map.get(known, "kind"),
      details: Map.get(known, "details"),
      exit_code: Map.get(known, "exit_code"),
      stderr: Map.get(known, "stderr"),
      stderr_truncated?: Map.get(known, "stderr_truncated"),
      extra: extra
    }
  end

  @spec from_map(map()) :: t()
  def from_map(map), do: parse!(map)

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = event) do
    %{
      "type" => event.type,
      "timestamp" => event.timestamp,
      "severity" => event.severity,
      "message" => event.message,
      "kind" => event.kind,
      "details" => event.details,
      "exit_code" => event.exit_code,
      "stderr" => event.stderr,
      "stderr_truncated" => event.stderr_truncated?
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(event.extra)
  end
end
