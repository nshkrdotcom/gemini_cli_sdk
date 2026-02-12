defmodule GeminiCliSdk do
  @moduledoc """
  An Elixir SDK for the Gemini CLI.

  Provides streaming and synchronous execution of Gemini CLI prompts,
  session management, and typed event parsing.

  ## Streaming

      GeminiCliSdk.execute("Explain OTP", %GeminiCliSdk.Options{model: GeminiCliSdk.Models.fast_model()})
      |> Enum.each(fn event ->
        case event do
          %GeminiCliSdk.Types.MessageEvent{role: "assistant", content: text} ->
            IO.write(text)
          _ -> :ok
        end
      end)

  ## Synchronous

      {:ok, response} = GeminiCliSdk.run("What is Elixir?")

  ## Session Management

      {:ok, sessions} = GeminiCliSdk.list_sessions()

      GeminiCliSdk.resume_session("latest")
      |> Enum.each(&IO.inspect/1)
  """

  alias GeminiCliSdk.{Error, Options, Types}

  @type event :: Types.stream_event()

  # --- Streaming execution ---

  @doc """
  Starts a Gemini CLI session and returns a lazy stream of typed events.

  The stream is backed by `Stream.resource/3`. It spawns the `gemini` subprocess
  with `--output-format stream-json` and `--prompt` carrying the prompt text, then
  yields one event struct per JSONL line. The subprocess is killed and cleaned up
  when the stream is halted, fully consumed, or the owning process dies.
  """
  @spec execute(String.t(), Options.t()) :: Enumerable.t(event())
  def execute(prompt, opts \\ %Options{}) do
    opts = Options.validate!(opts)
    GeminiCliSdk.Stream.execute(prompt, opts)
  end

  # --- Synchronous execution ---

  @doc """
  Executes a prompt and blocks until the CLI produces a final result.

  Internally calls `execute/2` and reduces the stream, collecting assistant
  message text. Returns `{:ok, response_text}` on success or
  `{:error, %Error{}}` on any failure.
  """
  @spec run(String.t(), Options.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def run(prompt, opts \\ %Options{}) do
    prompt
    |> execute(opts)
    |> Enum.reduce({nil, ""}, fn
      %Types.MessageEvent{role: "assistant", content: text}, {status, acc} ->
        {status, acc <> (text || "")}

      %Types.ResultEvent{status: "success"}, {_status, acc} ->
        {:ok, acc}

      %Types.ResultEvent{status: status, error: error}, {_status, _acc} ->
        {:error,
         Error.new(kind: :command_failed, message: error || "CLI returned status: #{status}")}

      %Types.ErrorEvent{severity: "fatal", message: msg}, {_status, _acc} ->
        {:error, Error.new(kind: :command_failed, message: msg)}

      _event, acc ->
        acc
    end)
    |> case do
      {:ok, text} -> {:ok, text}
      {:error, _} = error -> error
      {nil, _} -> {:error, Error.new(kind: :no_result, message: "No result received from stream")}
    end
  end

  # --- Session management ---

  @doc """
  Lists available sessions for the current project.

  Runs `gemini --list-sessions` and returns the raw output.
  """
  @spec list_sessions(keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  defdelegate list_sessions(opts \\ []), to: GeminiCliSdk.Session, as: :list

  @doc """
  Resumes a previous session and returns a streaming event enumerable.
  """
  @spec resume_session(String.t(), Options.t(), String.t() | nil) :: Enumerable.t(event())
  defdelegate resume_session(session_id, opts \\ %Options{}, prompt \\ nil),
    to: GeminiCliSdk.Session,
    as: :resume

  @doc """
  Deletes a session by index or ID.
  """
  @spec delete_session(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  defdelegate delete_session(identifier, opts \\ []), to: GeminiCliSdk.Session, as: :delete

  # --- Utility ---

  @doc """
  Returns the installed Gemini CLI version string.
  """
  @spec version() :: {:ok, String.t()} | {:error, Error.t()}
  def version do
    GeminiCliSdk.Command.run(["--version"])
  end
end
