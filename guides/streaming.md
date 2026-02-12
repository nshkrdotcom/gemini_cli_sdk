# Streaming

The streaming API is the core of GeminiCliSdk. It returns a lazy `Enumerable` backed by `Stream.resource/3`, yielding typed event structs as the Gemini CLI produces output.

## Basic Usage

```elixir
GeminiCliSdk.execute("Explain pattern matching")
|> Enum.each(fn event ->
  case event do
    %GeminiCliSdk.Types.InitEvent{model: model} ->
      IO.puts("Session started with model: #{model}")

    %GeminiCliSdk.Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)

    %GeminiCliSdk.Types.ResultEvent{status: "success", stats: stats} ->
      IO.puts("\n\nTokens used: #{stats.total_tokens}")

    %GeminiCliSdk.Types.ErrorEvent{message: msg} ->
      IO.puts(:stderr, "Error: #{msg}")

    _ ->
      :ok
  end
end)
```

## Event Types

Every line of JSONL output from the CLI is parsed into one of these structs:

| Struct | Description |
|--------|-------------|
| `Types.InitEvent` | Session initialized. Contains `session_id` and `model`. |
| `Types.MessageEvent` | A message chunk. Has `role` (`"user"` or `"assistant"`) and `content`. |
| `Types.ToolUseEvent` | The model is invoking a tool. Contains `name` and `input`. |
| `Types.ToolResultEvent` | A tool returned a result. Contains `name` and `output`. |
| `Types.ErrorEvent` | An error occurred. Has `severity` and `message`. |
| `Types.ResultEvent` | Final result. Has `status` (`"success"` or `"error"`) and `stats`. |

## Lazy Evaluation

The stream is lazy -- events are only produced as you consume them. This means you can:

### Take a prefix

```elixir
# Get just the first 5 events
first_five =
  GeminiCliSdk.execute("Write a long essay")
  |> Enum.take(5)
```

When you halt the stream early (via `Enum.take`, `Stream.take_while`, etc.), the subprocess is automatically killed and cleaned up.

### Filter events

```elixir
# Only assistant messages
GeminiCliSdk.execute("Explain OTP")
|> Stream.filter(&match?(%GeminiCliSdk.Types.MessageEvent{role: "assistant"}, &1))
|> Enum.each(fn %{content: text} -> IO.write(text) end)
```

### Collect into a structure

```elixir
# Build a conversation log
events =
  GeminiCliSdk.execute("List 3 Elixir libraries")
  |> Enum.to_list()

messages =
  events
  |> Enum.filter(&match?(%GeminiCliSdk.Types.MessageEvent{}, &1))
  |> Enum.map(fn %{role: role, content: content} -> {role, content} end)
```

## Backpressure

Because the stream is backed by `Stream.resource/3`, backpressure is natural. If your consumer is slow, the stream simply waits for the next `receive` call. The subprocess buffers output in the transport layer (up to 1MB for stdout).

## Timeouts

Set `timeout_ms` in options to limit how long the stream waits for each event:

```elixir
GeminiCliSdk.execute("Complex analysis", %GeminiCliSdk.Options{timeout_ms: 120_000})
|> Enum.to_list()
```

If the timeout is reached, a `Types.ErrorEvent` with a timeout message is emitted and the subprocess is cleaned up.

## Cleanup

The stream guarantees cleanup in all cases:

- **Full consumption** (`Enum.to_list/1`, `Enum.each/2`): cleanup runs after the last event
- **Early halt** (`Enum.take/2`, `Stream.take_while/2`): subprocess is killed immediately
- **Process death**: the transport GenServer is linked and will clean up the OS process

## Tool Use Events

When the model invokes tools, you'll see `ToolUseEvent` and `ToolResultEvent` pairs:

```elixir
GeminiCliSdk.execute("List the files in the current directory")
|> Enum.each(fn event ->
  case event do
    %GeminiCliSdk.Types.ToolUseEvent{name: name, input: input} ->
      IO.puts("Tool call: #{name}(#{inspect(input)})")

    %GeminiCliSdk.Types.ToolResultEvent{name: name, output: output} ->
      IO.puts("Tool result: #{name} -> #{inspect(output)}")

    %GeminiCliSdk.Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)

    _ ->
      :ok
  end
end)
```
