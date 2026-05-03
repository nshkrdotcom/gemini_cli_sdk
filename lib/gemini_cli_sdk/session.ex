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
      case parse_entry_line(line) do
        {:ok, entry} -> [entry | acc]
        :error -> acc
      end
    end)
    |> Enum.reverse()
  end

  defp parse_entry_line(line) do
    with {:ok, index, rest} <- split_index(String.trim(line)),
         {:ok, label, id} <- split_label_and_id(rest) do
      {:ok,
       %Entry{
         id: id,
         index: index,
         label: label,
         raw_line: line
       }}
    else
      :error -> :error
    end
  end

  defp split_index(line) do
    case :binary.match(line, ".") do
      {dot_at, 1} ->
        index_text = binary_part(line, 0, dot_at)
        rest = binary_part(line, dot_at + 1, byte_size(line) - dot_at - 1)

        with true <- digits_only?(index_text),
             {index, ""} <- Integer.parse(index_text) do
          {:ok, index, String.trim_leading(rest)}
        else
          _ -> :error
        end

      :nomatch ->
        :error
    end
  end

  defp split_label_and_id(rest) do
    trimmed = String.trim(rest)

    with true <- String.ends_with?(trimmed, "]"),
         [_first | _rest] = parts <- String.split(trimmed, "["),
         id_part <- List.last(parts),
         label_parts <- Enum.drop(parts, -1),
         id <- id_part |> String.trim_trailing("]") |> String.trim(),
         label <- label_parts |> Enum.join("[") |> String.trim(),
         true <- id != "",
         true <- label != "" do
      {:ok, label, id}
    else
      _ -> :error
    end
  end

  defp digits_only?(value) when is_binary(value) and value != "" do
    value
    |> String.to_charlist()
    |> Enum.all?(&(&1 in ?0..?9))
  end

  defp digits_only?(_value), do: false
end
