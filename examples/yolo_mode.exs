# YOLO Mode Example
#
# Demonstrates running Gemini with auto-approval (--yolo flag).
# In YOLO mode, all tool calls are automatically approved without prompting.
#
# WARNING: Use with caution. YOLO mode allows the CLI to execute tools
# without confirmation.
#
# Usage:
#   mix run examples/yolo_mode.exs

alias GeminiCliSdk.Types

IO.puts("=== YOLO Mode ===\n")
IO.puts("Running with auto-approval enabled...\n")

opts = %GeminiCliSdk.Options{
  model: GeminiCliSdk.Models.fast_model(),
  yolo: true,
  timeout_ms: 120_000
}

GeminiCliSdk.execute("Read the mix.exs file and tell me the project name and version", opts)
|> Enum.each(fn event ->
  case event do
    %Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)

    %Types.ToolUseEvent{tool_name: name} ->
      IO.puts(:stderr, "[auto-approved] #{name}")

    %Types.ResultEvent{status: status} ->
      IO.puts("\n\n[#{status}]")

    %Types.ErrorEvent{message: msg} ->
      IO.puts(:stderr, "[error] #{msg}")

    _ ->
      :ok
  end
end)
