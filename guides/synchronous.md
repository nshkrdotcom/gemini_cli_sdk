# Synchronous Execution

For simple request/response patterns where you don't need to process individual events, use `GeminiCliSdk.run/2`.

## Basic Usage

```elixir
{:ok, response} = GeminiCliSdk.run("What is the BEAM VM?")
IO.puts(response)
```

## How It Works

`run/2` internally calls `execute/2` and reduces the event stream:

1. Collects all `MessageEvent` chunks with `role: "assistant"` into a single string
2. Returns `{:ok, text}` if a `ResultEvent` with `status: "success"` is received
3. Returns `{:error, %Error{}}` if a fatal `ErrorEvent` or error `ResultEvent` is received

Gemini's non-streaming management helpers (`list_sessions/1`, `delete_session/2`,
and `version/0`) use the shared `CliSubprocessCore.Command.run/2` lane under
the same public API.

## Error Handling

```elixir
case GeminiCliSdk.run("Explain monads") do
  {:ok, text} ->
    IO.puts(text)

  {:error, %GeminiCliSdk.Error{kind: kind, message: msg}} ->
    IO.puts(:stderr, "Failed (#{kind}): #{msg}")
end
```

Common error kinds:

| Kind | Cause |
|------|-------|
| `:cli_not_found` | The `gemini` binary is not installed or not in PATH |
| `:command_failed` | The CLI returned a non-success result |
| `:no_result` | The stream ended without producing a result event |

## With Options

```elixir
opts = %GeminiCliSdk.Options{
  model: GeminiCliSdk.Models.fast_model(),
  yolo: true,
  timeout_ms: 60_000
}

case GeminiCliSdk.run("Refactor this function", opts) do
  {:ok, result} -> IO.puts(result)
  {:error, error} -> IO.puts(:stderr, "Error: #{error.message}")
end
```

## When to Use run/2 vs execute/2

| Use `run/2` when... | Use `execute/2` when... |
|---------------------|------------------------|
| You need the final text only | You want real-time streaming output |
| Simple request/response pattern | You need to process tool use events |
| You want `{:ok, _} / {:error, _}` | You want fine-grained event handling |
| Scripting and automation | Interactive applications |
