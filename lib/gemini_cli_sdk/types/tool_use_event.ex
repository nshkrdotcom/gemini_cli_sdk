defmodule GeminiCliSdk.Types.ToolUseEvent do
  @moduledoc "A tool call request event."

  alias CliSubprocessCore.Schema.Conventions
  alias GeminiCliSdk.Schema

  @known_fields ["type", "timestamp", "tool_name", "tool_id", "parameters"]
  @schema Zoi.map(
            %{
              "type" => Zoi.default(Conventions.optional_trimmed_string(), "tool_use"),
              "timestamp" => Conventions.optional_trimmed_string(),
              "tool_name" => Zoi.default(Conventions.optional_trimmed_string(), ""),
              "tool_id" => Zoi.default(Conventions.optional_trimmed_string(), ""),
              "parameters" => Zoi.default(Conventions.optional_map(), %{})
            },
            unrecognized_keys: :preserve
          )

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          tool_name: String.t(),
          tool_id: String.t(),
          parameters: map(),
          extra: map()
        }

  defstruct type: "tool_use",
            timestamp: nil,
            tool_name: "",
            tool_id: "",
            parameters: %{},
            extra: %{}

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec parse(map() | t()) ::
          {:ok, t()}
          | {:error, {:invalid_tool_use_event, CliSubprocessCore.Schema.error_detail()}}
  def parse(%__MODULE__{} = event), do: {:ok, event}

  def parse(map) when is_map(map) do
    case Schema.parse(@schema, map, :invalid_tool_use_event) do
      {:ok, parsed} ->
        {known, extra} = Schema.split_extra(parsed, @known_fields)

        {:ok,
         %__MODULE__{
           type: Map.get(known, "type", "tool_use"),
           timestamp: Map.get(known, "timestamp"),
           tool_name: Map.get(known, "tool_name", ""),
           tool_id: Map.get(known, "tool_id", ""),
           parameters: Map.get(known, "parameters", %{}),
           extra: extra
         }}

      {:error, {:invalid_tool_use_event, details}} ->
        {:error, {:invalid_tool_use_event, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = event), do: event

  def parse!(map) when is_map(map) do
    parsed = Schema.parse!(@schema, map, :invalid_tool_use_event)
    {known, extra} = Schema.split_extra(parsed, @known_fields)

    %__MODULE__{
      type: Map.get(known, "type", "tool_use"),
      timestamp: Map.get(known, "timestamp"),
      tool_name: Map.get(known, "tool_name", ""),
      tool_id: Map.get(known, "tool_id", ""),
      parameters: Map.get(known, "parameters", %{}),
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
      "tool_name" => event.tool_name,
      "tool_id" => event.tool_id,
      "parameters" => event.parameters
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(event.extra)
  end
end
