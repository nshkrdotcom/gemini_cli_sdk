defmodule GeminiCliSdk.Error do
  @moduledoc "Unified error type for the Gemini CLI SDK."

  @enforce_keys [:kind, :message]
  defexception [:kind, :message, :cause, :details, :context, :exit_code]

  @type kind ::
          :cli_not_found
          | :command_failed
          | :command_timeout
          | :command_execution_failed
          | :stream_start_failed
          | :stream_timeout
          | :transport_error
          | :parse_error
          | :json_decode_error
          | :unknown_event_type
          | :invalid_event
          | :invalid_configuration
          | :execution_failed
          | :no_result
          | :auth_error
          | :input_error
          | :config_error
          | :user_cancelled
          | :unknown

  @type t :: %__MODULE__{
          kind: kind(),
          message: String.t(),
          cause: term(),
          details: String.t() | nil,
          context: map() | nil,
          exit_code: integer() | nil
        }

  @impl true
  def message(%__MODULE__{message: msg}), do: msg

  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    %__MODULE__{
      kind: Keyword.fetch!(opts, :kind),
      message: Keyword.get(opts, :message, ""),
      cause: Keyword.get(opts, :cause),
      details: Keyword.get(opts, :details),
      context: Keyword.get(opts, :context),
      exit_code: Keyword.get(opts, :exit_code)
    }
  end

  @exit_code_map %{
    41 => :auth_error,
    42 => :input_error,
    52 => :config_error,
    130 => :user_cancelled
  }

  @spec from_exit_code(integer()) :: :ok | t()
  def from_exit_code(0), do: :ok

  def from_exit_code(code) when is_map_key(@exit_code_map, code) do
    kind = Map.fetch!(@exit_code_map, code)

    new(
      kind: kind,
      message: "CLI exited with code #{code}",
      exit_code: code
    )
  end

  def from_exit_code(code) do
    new(
      kind: :command_failed,
      message: "CLI exited with code #{code}",
      exit_code: code
    )
  end

  @spec normalize(term(), keyword()) :: t()
  def normalize({:transport, reason}, opts) do
    kind = Keyword.get(opts, :kind, :transport_error)
    message = "Transport error: not connected"

    new(
      kind: kind,
      message: message,
      cause: {:transport, reason}
    )
  end

  def normalize(:timeout, opts) do
    kind = Keyword.get(opts, :kind, :stream_timeout)

    new(
      kind: kind,
      message: "Operation timed out"
    )
  end

  def normalize(reason, opts) when is_binary(reason) do
    kind = Keyword.get(opts, :kind, :unknown)

    new(
      kind: kind,
      message: reason,
      cause: reason
    )
  end

  def normalize(reason, opts) when is_atom(reason) do
    kind = Keyword.get(opts, :kind, :unknown)

    new(
      kind: kind,
      message: Atom.to_string(reason),
      cause: reason
    )
  end

  def normalize(reason, opts) do
    kind = Keyword.get(opts, :kind, :unknown)

    new(
      kind: kind,
      message: inspect(reason),
      cause: reason
    )
  end
end
