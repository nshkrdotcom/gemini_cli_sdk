# Streaming Example
#
# Streams events from Gemini CLI in real-time, printing assistant output
# as it arrives and showing stats at the end.
#
# Usage:
#   mix run examples/streaming.exs

alias GeminiCliSdk.Types

IO.puts("=== Streaming ===\n")

GeminiCliSdk.execute("Explain the BEAM VM in 3 paragraphs")
|> Enum.each(fn event ->
  case event do
    %Types.InitEvent{model: model, session_id: sid} ->
      IO.puts(:stderr, "[init] model=#{model} session=#{sid}\n")

    %Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)

    %Types.ToolUseEvent{name: name} ->
      IO.puts(:stderr, "\n[tool_use] #{name}")

    %Types.ToolResultEvent{name: name} ->
      IO.puts(:stderr, "[tool_result] #{name}")

    %Types.ResultEvent{status: status, stats: stats} ->
      IO.puts("\n")
      IO.puts(:stderr, "[result] status=#{status}")

      if stats do
        IO.puts(
          :stderr,
          "  tokens: #{stats.total_tokens} (in=#{stats.input_tokens}, out=#{stats.output_tokens})"
        )

        IO.puts(:stderr, "  duration: #{stats.duration_ms}ms")
      end

    %Types.ErrorEvent{severity: severity, message: msg} ->
      IO.puts(:stderr, "[error] #{severity}: #{msg}")

    _ ->
      :ok
  end
end)
