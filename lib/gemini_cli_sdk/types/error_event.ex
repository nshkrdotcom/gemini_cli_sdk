defmodule GeminiCliSdk.Types.ErrorEvent do
  @moduledoc "A non-fatal error or warning event."

  @type t :: %__MODULE__{
          type: String.t(),
          timestamp: String.t() | nil,
          severity: String.t(),
          message: String.t(),
          kind: atom() | String.t() | nil,
          details: map() | nil,
          exit_code: integer() | nil,
          stderr: String.t() | nil,
          stderr_truncated?: boolean() | nil
        }

  defstruct type: "error",
            timestamp: nil,
            severity: "error",
            message: "",
            kind: nil,
            details: nil,
            exit_code: nil,
            stderr: nil,
            stderr_truncated?: nil

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"] || "error",
      timestamp: map["timestamp"],
      severity: map["severity"] || "error",
      message: map["message"] || "",
      kind: map["kind"],
      details: map["details"],
      exit_code: map["exit_code"],
      stderr: map["stderr"],
      stderr_truncated?: map["stderr_truncated"]
    }
  end
end
