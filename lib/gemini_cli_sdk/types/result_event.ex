defmodule GeminiCliSdk.Types.ResultEvent do
  @moduledoc "Final session result event."

  alias CliSubprocessCore.Schema.Conventions
  alias GeminiCliSdk.Schema
  alias GeminiCliSdk.Types.Stats

  @known_fields ["type", "timestamp", "status", "error", "stats"]
  @schema Zoi.map(
            %{
              "type" => Zoi.default(Conventions.optional_trimmed_string(), "result"),
              "timestamp" => Conventions.optional_trimmed_string(),
              "status" => Zoi.default(Conventions.optional_trimmed_string(), ""),
              "error" => Conventions.optional_any(),
              "stats" => Zoi.optional(Zoi.nullish(Stats.schema()))
            },
            unrecognized_keys: :preserve
          )

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          status: String.t(),
          error: String.t() | nil,
          stats: Stats.t() | nil,
          extra: map()
        }

  defstruct type: "result",
            timestamp: nil,
            status: "",
            error: nil,
            stats: nil,
            extra: %{}

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec parse(map() | t()) ::
          {:ok, t()} | {:error, {:invalid_result_event, CliSubprocessCore.Schema.error_detail()}}
  def parse(%__MODULE__{} = event), do: {:ok, event}

  def parse(map) when is_map(map) do
    case Schema.parse(@schema, map, :invalid_result_event) do
      {:ok, parsed} ->
        {known, extra} = Schema.split_extra(parsed, @known_fields)

        {:ok,
         %__MODULE__{
           type: Map.get(known, "type", "result"),
           timestamp: Map.get(known, "timestamp"),
           status: Map.get(known, "status", ""),
           error: extract_error_message(Map.get(known, "error")),
           stats: Stats.parse!(Map.get(known, "stats")),
           extra: extra
         }}

      {:error, {:invalid_result_event, details}} ->
        {:error, {:invalid_result_event, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = event), do: event

  def parse!(map) when is_map(map) do
    parsed = Schema.parse!(@schema, map, :invalid_result_event)
    {known, extra} = Schema.split_extra(parsed, @known_fields)

    %__MODULE__{
      type: Map.get(known, "type", "result"),
      timestamp: Map.get(known, "timestamp"),
      status: Map.get(known, "status", ""),
      error: extract_error_message(Map.get(known, "error")),
      stats: Stats.parse!(Map.get(known, "stats")),
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
      "status" => event.status,
      "error" => event.error,
      "stats" => event.stats && Stats.to_map(event.stats)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(event.extra)
  end

  defp extract_error_message(nil), do: nil
  defp extract_error_message(%{"message" => msg}) when is_binary(msg), do: msg
  defp extract_error_message(msg) when is_binary(msg), do: msg
  defp extract_error_message(other), do: inspect(other)
end
