defmodule GeminiCliSdk.Types.ToolUseEvent do
  @moduledoc "A tool call request event."

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          tool_name: String.t(),
          tool_id: String.t(),
          parameters: map()
        }

  defstruct type: "tool_use",
            timestamp: nil,
            tool_name: "",
            tool_id: "",
            parameters: %{}

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"] || "tool_use",
      timestamp: map["timestamp"],
      tool_name: map["tool_name"] || "",
      tool_id: map["tool_id"] || "",
      parameters: map["parameters"] || %{}
    }
  end
end
