defmodule GeminiCliSdk.Types.InitEvent do
  @moduledoc "Session initialization event."

  alias CliSubprocessCore.Schema.Conventions
  alias GeminiCliSdk.Schema

  @known_fields ["type", "timestamp", "session_id", "model"]
  @schema Zoi.map(
            %{
              "type" => Zoi.default(Conventions.optional_trimmed_string(), "init"),
              "timestamp" => Conventions.optional_trimmed_string(),
              "session_id" => Zoi.default(Conventions.optional_trimmed_string(), ""),
              "model" => Zoi.default(Conventions.optional_trimmed_string(), "")
            },
            unrecognized_keys: :preserve
          )

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          session_id: String.t(),
          model: String.t(),
          extra: map()
        }

  defstruct type: "init",
            timestamp: nil,
            session_id: "",
            model: "",
            extra: %{}

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec parse(map() | t()) ::
          {:ok, t()} | {:error, {:invalid_init_event, CliSubprocessCore.Schema.error_detail()}}
  def parse(%__MODULE__{} = event), do: {:ok, event}

  def parse(map) when is_map(map) do
    case Schema.parse(@schema, map, :invalid_init_event) do
      {:ok, parsed} ->
        {known, extra} = Schema.split_extra(parsed, @known_fields)

        {:ok,
         %__MODULE__{
           type: Map.get(known, "type", "init"),
           timestamp: Map.get(known, "timestamp"),
           session_id: Map.get(known, "session_id", ""),
           model: Map.get(known, "model", ""),
           extra: extra
         }}

      {:error, {:invalid_init_event, details}} ->
        {:error, {:invalid_init_event, details}}
    end
  end

  @spec parse!(map() | t()) :: t()
  def parse!(%__MODULE__{} = event), do: event

  def parse!(map) when is_map(map) do
    parsed = Schema.parse!(@schema, map, :invalid_init_event)
    {known, extra} = Schema.split_extra(parsed, @known_fields)

    %__MODULE__{
      type: Map.get(known, "type", "init"),
      timestamp: Map.get(known, "timestamp"),
      session_id: Map.get(known, "session_id", ""),
      model: Map.get(known, "model", ""),
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
      "session_id" => event.session_id,
      "model" => event.model
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.merge(event.extra)
  end
end
