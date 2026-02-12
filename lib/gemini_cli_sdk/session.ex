defmodule GeminiCliSdk.Session do
  @moduledoc "Session management operations (list, resume, delete)."

  alias GeminiCliSdk.{Command, Options}

  @spec list(keyword()) :: {:ok, String.t()} | {:error, GeminiCliSdk.Error.t()}
  def list(opts \\ []) do
    Command.run(["--list-sessions"], opts)
  end

  @spec resume(String.t(), Options.t(), String.t() | nil) ::
          Enumerable.t(GeminiCliSdk.Types.stream_event())
  def resume(session_id, %Options{} = opts \\ %Options{}, prompt \\ nil) do
    opts = %{opts | resume: session_id}

    case prompt do
      nil -> GeminiCliSdk.Stream.execute("", opts)
      text -> GeminiCliSdk.Stream.execute(text, opts)
    end
  end

  @spec delete(String.t(), keyword()) :: {:ok, String.t()} | {:error, GeminiCliSdk.Error.t()}
  def delete(identifier, opts \\ []) do
    Command.run(["--delete-session", identifier], opts)
  end
end
