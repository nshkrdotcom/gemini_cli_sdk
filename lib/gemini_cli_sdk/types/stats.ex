defmodule GeminiCliSdk.Types.Stats do
  @moduledoc "Aggregated session statistics."

  @type t :: %__MODULE__{
          total_tokens: non_neg_integer(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          duration_ms: non_neg_integer(),
          tool_calls: non_neg_integer()
        }

  defstruct total_tokens: 0,
            input_tokens: 0,
            output_tokens: 0,
            duration_ms: 0,
            tool_calls: 0

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      total_tokens: map["total_tokens"] || 0,
      input_tokens: map["input_tokens"] || 0,
      output_tokens: map["output_tokens"] || 0,
      duration_ms: map["duration_ms"] || 0,
      tool_calls: map["tool_calls"] || 0
    }
  end
end
