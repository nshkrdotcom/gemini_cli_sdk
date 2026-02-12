defmodule GeminiCliSdk.Types.MessageEvent do
  @moduledoc "A message event (user or assistant)."

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          role: String.t(),
          content: String.t(),
          delta: boolean() | nil
        }

  defstruct type: "message",
            timestamp: nil,
            role: "",
            content: "",
            delta: nil

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"] || "message",
      timestamp: map["timestamp"],
      role: map["role"] || "",
      content: map["content"] || "",
      delta: map["delta"]
    }
  end
end
