# Tool Use Example
#
# Demonstrates capturing tool use and tool result events from the stream.
# This requires the CLI to have tools enabled (e.g., file operations).
#
# Usage:
#   mix run examples/tool_use.exs

alias GeminiCliSdk.Types

IO.puts("=== Tool Use Events ===\n")

opts = %GeminiCliSdk.Options{
  model: GeminiCliSdk.Models.fast_model(),
  timeout_ms: 120_000
}

GeminiCliSdk.execute(
  "List the files in the current directory and tell me what this project is about",
  opts
)
|> Enum.each(fn event ->
  case event do
    %Types.InitEvent{} ->
      IO.puts(:stderr, "[session started]")

    %Types.ToolUseEvent{tool_name: name, parameters: params} ->
      IO.puts(:stderr, "\n>> Tool call: #{name}")
      IO.puts(:stderr, "   Parameters: #{inspect(params)}")

    %Types.ToolResultEvent{tool_id: id, output: output} ->
      preview = if is_binary(output), do: String.slice(output, 0, 200), else: inspect(output)
      IO.puts(:stderr, "<< Tool result: #{id}")
      IO.puts(:stderr, "   Output: #{preview}...")

    %Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)

    %Types.ResultEvent{status: status} ->
      IO.puts("\n\n[done: #{status}]")

    %Types.ErrorEvent{message: msg} ->
      IO.puts(:stderr, "[error] #{msg}")

    _ ->
      :ok
  end
end)
