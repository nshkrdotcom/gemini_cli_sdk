defmodule GeminiCliSdk.Types.InitEvent do
  @moduledoc "Session initialization event."

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          session_id: String.t(),
          model: String.t()
        }

  defstruct type: "init",
            timestamp: nil,
            session_id: "",
            model: ""

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"] || "init",
      timestamp: map["timestamp"],
      session_id: map["session_id"] || "",
      model: map["model"] || ""
    }
  end
end
