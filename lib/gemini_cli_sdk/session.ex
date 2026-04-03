defmodule GeminiCliSdk.Session do
  @moduledoc "Session management operations (list, resume, delete)."

  alias GeminiCliSdk.{Command, Options}

  defmodule Entry do
    @moduledoc "Structured Gemini CLI resumable session entry."

    @enforce_keys [:id, :label]
    defstruct [:id, :label, :index, raw_line: nil]

    @type t :: %__MODULE__{
            id: String.t(),
            label: String.t(),
            index: pos_integer() | nil,
            raw_line: String.t() | nil
          }
  end

  @entry_regex ~r/^\s*(?<index>\d+)\.\s+(?<label>.+?)\s+\[(?<id>[^\]]+)\]\s*$/

  @spec list(keyword()) :: {:ok, String.t()} | {:error, GeminiCliSdk.Error.t()}
  def list(opts \\ []) do
    Command.run(["--list-sessions"], opts)
  end

  @spec list_entries(keyword()) :: {:ok, [Entry.t()]} | {:error, GeminiCliSdk.Error.t()}
  def list_entries(opts \\ []) do
    with {:ok, output} <- list(opts) do
      {:ok, parse_list_output(output)}
    end
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

  @spec parse_list_output(String.t()) :: [Entry.t()]
  def parse_list_output(output) when is_binary(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reduce([], fn line, acc ->
      case Regex.named_captures(@entry_regex, line) do
        %{"id" => id, "index" => index, "label" => label} ->
          [
            %Entry{
              id: String.trim(id),
              index: String.to_integer(index),
              label: String.trim(label),
              raw_line: line
            }
            | acc
          ]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end
end
