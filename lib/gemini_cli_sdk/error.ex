defmodule GeminiCliSdk.Error do
  @moduledoc "Unified error type for the Gemini CLI SDK."

  alias CliSubprocessCore.ProviderCLI.ErrorRuntimeFailure
  alias CliSubprocessCore.Transport.Error, as: CoreTransportError

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
          | :transport_exit
          | :parse_error
          | :json_decode_error
          | :unknown_event_type
          | :invalid_event
          | :invalid_configuration
          | :config_invalid
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

  @spec from_runtime_failure(ErrorRuntimeFailure.t(), keyword()) :: t()
  def from_runtime_failure(%ErrorRuntimeFailure{} = failure, opts \\ []) when is_list(opts) do
    extra_context =
      opts
      |> Keyword.get(:context, %{})
      |> normalize_context()

    new(
      kind: runtime_failure_kind(failure),
      message: Keyword.get(opts, :message, failure.message),
      cause: Keyword.get(opts, :cause, failure.cause || failure),
      details: Keyword.get(opts, :details, failure.stderr),
      context: Map.merge(failure.context || %{}, extra_context),
      exit_code: Keyword.get(opts, :exit_code, failure.exit_code)
    )
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
  def normalize(%__MODULE__{} = error, opts) do
    new(
      kind: Keyword.get(opts, :kind, error.kind),
      message: Keyword.get(opts, :message, error.message),
      cause: Keyword.get(opts, :cause, error.cause),
      details: Keyword.get(opts, :details, error.details),
      context: Keyword.get(opts, :context, error.context),
      exit_code: Keyword.get(opts, :exit_code, error.exit_code)
    )
  end

  def normalize(%ErrorRuntimeFailure{} = failure, opts) do
    from_runtime_failure(failure, opts)
  end

  def normalize({:transport, %CoreTransportError{} = error}, opts) do
    normalize(error, opts)
  end

  def normalize(%CoreTransportError{} = error, opts) do
    kind = Keyword.get(opts, :kind, :transport_error)

    new(
      kind: kind,
      message: transport_message(error.reason),
      cause: Keyword.get(opts, :cause, error),
      details: Keyword.get(opts, :details),
      context: Map.merge(error.context || %{}, normalize_context(Keyword.get(opts, :context))),
      exit_code: Keyword.get(opts, :exit_code)
    )
  end

  def normalize({:transport, reason}, opts) do
    kind = Keyword.get(opts, :kind, :transport_error)
    message = transport_message(reason)

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

  defp runtime_failure_kind(%ErrorRuntimeFailure{kind: :auth_error}), do: :auth_error
  defp runtime_failure_kind(%ErrorRuntimeFailure{kind: :cli_not_found}), do: :cli_not_found
  defp runtime_failure_kind(%ErrorRuntimeFailure{kind: :cwd_not_found}), do: :config_invalid
  defp runtime_failure_kind(%ErrorRuntimeFailure{kind: :process_exit}), do: :transport_exit
  defp runtime_failure_kind(%ErrorRuntimeFailure{kind: :transport_error}), do: :transport_error

  defp normalize_context(nil), do: %{}
  defp normalize_context(context) when is_map(context), do: context
  defp normalize_context(context) when is_list(context), do: Map.new(context)
  defp normalize_context(context), do: %{context: context}

  defp transport_message(:not_connected), do: "Transport not connected"
  defp transport_message(reason), do: "Transport error: #{inspect(reason)}"
end
