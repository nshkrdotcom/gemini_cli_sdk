defmodule GeminiCliSdk.Types.MessageEvent do
  @moduledoc "A message event (user or assistant)."

  alias CliSubprocessCore.Schema.Conventions
  alias GeminiCliSdk.Schema

  @known_fields ["type", "timestamp", "role", "content", "delta"]
  @schema Zoi.map(
            %{
              "type" => Zoi.default(Conventions.optional_trimmed_string(), "message"),
              "timestamp" => Conventions.optional_trimmed_string(),
              "role" => Zoi.default(Conventions.optional_trimmed_string(), ""),
              "content" => Zoi.default(Conventions.optional_trimmed_string(), ""),
              "delta" => Zoi.optional(Zoi.nullish(Zoi.boolean()))
            },
            unrecognized_keys: :preserve
          )

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          role: String.t(),
          content: String.t(),
          delta: boolean() | nil,
          extra: map()
        }

  defstruct type: "message",
            timestamp: nil,
            role: "",
            content: "",
            delta: nil,
            extra: %{}

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec parse(map() | t()) ::
          {:ok, t()} | {:error, {:invalid_message_event, CliSubprocessCore.Schema.error_detail()}}
  def parse(%__MODULE__{} = event), do: {:ok, event}

  def parse(map) when is_map(map) do
    case Schema.parse(@schema, map, :invalid_message_event) do
      {:ok, parsed} ->
        {known, extra} = Schema.split_extra(parsed, @known_fields)

        {:ok,
         %__MODULE__{
           type: Map.get(known, "type", "message"),
           timestamp: Map.get(known, "timestamp"),
           role: Map.get(known, "role", ""),
           content: Map.get(known, "content", ""),
           delta: Map.get(known, "delta"),
           extra: extra
         }}

      {:error, {:invalid_message_event, details}} ->
        {:error, {:invalid_message_event, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = event), do: event

  def parse!(map) when is_map(map) do
    parsed = Schema.parse!(@schema, map, :invalid_message_event)
    {known, extra} = Schema.split_extra(parsed, @known_fields)

    %__MODULE__{
      type: Map.get(known, "type", "message"),
      timestamp: Map.get(known, "timestamp"),
      role: Map.get(known, "role", ""),
      content: Map.get(known, "content", ""),
      delta: Map.get(known, "delta"),
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
      "role" => event.role,
      "content" => event.content,
      "delta" => event.delta
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(event.extra)
  end
end
