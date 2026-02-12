defmodule GeminiCliSdk.Types.ResultEvent do
  @moduledoc "Final session result event."

  alias GeminiCliSdk.Types.Stats

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          status: String.t(),
          error: String.t() | nil,
          stats: Stats.t() | nil
        }

  defstruct type: "result",
            timestamp: nil,
            status: "",
            error: nil,
            stats: nil

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"] || "result",
      timestamp: map["timestamp"],
      status: map["status"] || "",
      error: map["error"],
      stats: Stats.from_map(map["stats"])
    }
  end
end
