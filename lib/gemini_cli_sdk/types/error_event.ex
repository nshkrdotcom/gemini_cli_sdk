defmodule GeminiCliSdk.Types.ErrorEvent do
  @moduledoc "A non-fatal error or warning event."

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          severity: String.t(),
          message: String.t()
        }

  defstruct type: "error",
            timestamp: nil,
            severity: "error",
            message: ""

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"] || "error",
      timestamp: map["timestamp"],
      severity: map["severity"] || "error",
      message: map["message"] || ""
    }
  end
end
