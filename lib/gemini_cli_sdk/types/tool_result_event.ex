defmodule GeminiCliSdk.Types.ToolResultEvent do
  @moduledoc "A tool execution result event."

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          tool_id: String.t(),
          status: String.t(),
          output: String.t() | nil,
          error: String.t() | nil
        }

  defstruct type: "tool_result",
            timestamp: nil,
            tool_id: "",
            status: "",
            output: nil,
            error: nil

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"] || "tool_result",
      timestamp: map["timestamp"],
      tool_id: map["tool_id"] || "",
      status: map["status"] || "",
      output: map["output"],
      error: map["error"]
    }
  end
end
