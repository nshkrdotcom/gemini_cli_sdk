defmodule GeminiCliSdk.Types.Stats do
  @moduledoc "Aggregated session statistics."

  alias GeminiCliSdk.Schema

  @known_fields ["total_tokens", "input_tokens", "output_tokens", "duration_ms", "tool_calls"]
  @schema Zoi.map(
            %{
              "total_tokens" => Zoi.default(Zoi.optional(Zoi.nullish(Zoi.integer(gte: 0))), 0),
              "input_tokens" => Zoi.default(Zoi.optional(Zoi.nullish(Zoi.integer(gte: 0))), 0),
              "output_tokens" => Zoi.default(Zoi.optional(Zoi.nullish(Zoi.integer(gte: 0))), 0),
              "duration_ms" => Zoi.default(Zoi.optional(Zoi.nullish(Zoi.integer(gte: 0))), 0),
              "tool_calls" => Zoi.default(Zoi.optional(Zoi.nullish(Zoi.integer(gte: 0))), 0)
            },
            unrecognized_keys: :preserve
          )

  @type t :: %__MODULE__{
          total_tokens: non_neg_integer(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          duration_ms: non_neg_integer(),
          tool_calls: non_neg_integer(),
          extra: map()
        }

  defstruct total_tokens: 0,
            input_tokens: 0,
            output_tokens: 0,
            duration_ms: 0,
            tool_calls: 0,
            extra: %{}

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec parse(map() | nil | t()) ::
          {:ok, t() | nil} | {:error, {:invalid_stats, CliSubprocessCore.Schema.error_detail()}}
  def parse(nil), do: {:ok, nil}
  def parse(%__MODULE__{} = stats), do: {:ok, stats}

  def parse(map) when is_map(map) do
    case Schema.parse(@schema, map, :invalid_stats) do
      {:ok, parsed} ->
        {known, extra} = Schema.split_extra(parsed, @known_fields)

        {:ok,
         %__MODULE__{
           total_tokens: Map.get(known, "total_tokens", 0),
           input_tokens: Map.get(known, "input_tokens", 0),
           output_tokens: Map.get(known, "output_tokens", 0),
           duration_ms: Map.get(known, "duration_ms", 0),
           tool_calls: Map.get(known, "tool_calls", 0),
           extra: extra
         }}

      {:error, {:invalid_stats, details}} ->
        {:error, {:invalid_stats, details}}
    end
  end

  @spec parse!(map() | nil | t()) :: t() | nil
  def parse!(nil), do: nil
  def parse!(%__MODULE__{} = stats), do: stats

  def parse!(map) when is_map(map) do
    parsed = Schema.parse!(@schema, map, :invalid_stats)
    {known, extra} = Schema.split_extra(parsed, @known_fields)

    %__MODULE__{
      total_tokens: Map.get(known, "total_tokens", 0),
      input_tokens: Map.get(known, "input_tokens", 0),
      output_tokens: Map.get(known, "output_tokens", 0),
      duration_ms: Map.get(known, "duration_ms", 0),
      tool_calls: Map.get(known, "tool_calls", 0),
      extra: extra
    }
  end

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil
  def from_map(map), do: parse!(map)

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = stats) do
    %{
      "total_tokens" => stats.total_tokens,
      "input_tokens" => stats.input_tokens,
      "output_tokens" => stats.output_tokens,
      "duration_ms" => stats.duration_ms,
      "tool_calls" => stats.tool_calls
    }
    |> Map.merge(stats.extra)
  end
end
