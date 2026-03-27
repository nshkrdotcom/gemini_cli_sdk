defmodule GeminiCliSdk.Types.ToolResultEvent do
  @moduledoc "A tool execution result event."

  alias CliSubprocessCore.Schema.Conventions
  alias GeminiCliSdk.Schema

  @known_fields ["type", "timestamp", "tool_id", "status", "output", "error"]
  @schema Zoi.map(
            %{
              "type" => Zoi.default(Conventions.optional_trimmed_string(), "tool_result"),
              "timestamp" => Conventions.optional_trimmed_string(),
              "tool_id" => Zoi.default(Conventions.optional_trimmed_string(), ""),
              "status" => Zoi.default(Conventions.optional_trimmed_string(), ""),
              "output" => Conventions.optional_any(),
              "error" => Conventions.optional_any()
            },
            unrecognized_keys: :preserve
          )

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          tool_id: String.t(),
          status: String.t(),
          output: String.t() | nil,
          error: String.t() | nil,
          extra: map()
        }

  defstruct type: "tool_result",
            timestamp: nil,
            tool_id: "",
            status: "",
            output: nil,
            error: nil,
            extra: %{}

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec parse(map() | t()) ::
          {:ok, t()}
          | {:error, {:invalid_tool_result_event, CliSubprocessCore.Schema.error_detail()}}
  def parse(%__MODULE__{} = event), do: {:ok, event}

  def parse(map) when is_map(map) do
    case Schema.parse(@schema, map, :invalid_tool_result_event) do
      {:ok, parsed} ->
        {known, extra} = Schema.split_extra(parsed, @known_fields)

        {:ok,
         %__MODULE__{
           type: Map.get(known, "type", "tool_result"),
           timestamp: Map.get(known, "timestamp"),
           tool_id: Map.get(known, "tool_id", ""),
           status: Map.get(known, "status", ""),
           output: normalize_optional_string(Map.get(known, "output")),
           error: normalize_optional_string(Map.get(known, "error")),
           extra: extra
         }}

      {:error, {:invalid_tool_result_event, details}} ->
        {:error, {:invalid_tool_result_event, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = event), do: event

  def parse!(map) when is_map(map) do
    parsed = Schema.parse!(@schema, map, :invalid_tool_result_event)
    {known, extra} = Schema.split_extra(parsed, @known_fields)

    %__MODULE__{
      type: Map.get(known, "type", "tool_result"),
      timestamp: Map.get(known, "timestamp"),
      tool_id: Map.get(known, "tool_id", ""),
      status: Map.get(known, "status", ""),
      output: normalize_optional_string(Map.get(known, "output")),
      error: normalize_optional_string(Map.get(known, "error")),
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
      "tool_id" => event.tool_id,
      "status" => event.status,
      "output" => event.output,
      "error" => event.error
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(event.extra)
  end

  defp normalize_optional_string(nil), do: nil
  defp normalize_optional_string(value) when is_binary(value), do: value
  defp normalize_optional_string(value), do: inspect(value)
end
