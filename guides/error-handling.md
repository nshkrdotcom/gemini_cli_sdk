# Error Handling

GeminiCliSdk provides structured error handling through the `GeminiCliSdk.Error` exception struct and typed error events in streams.

## Error Struct

```elixir
%GeminiCliSdk.Error{
  kind: :cli_not_found,          # Atom categorizing the error
  message: "gemini not found",   # Human-readable description
  exit_code: nil,                # OS process exit code (when available)
  cause: nil,                    # Underlying error (when wrapping)
  details: nil,                  # Additional context
  context: nil                   # Operation context
}
```

## Error Kinds

| Kind | Exit Code | Description |
|------|-----------|-------------|
| `:cli_not_found` | -- | The `gemini` binary was not found or an explicit `cli_command` path is invalid |
| `:auth_error` | 41 | Authentication failed (invalid API key, expired token) |
| `:input_error` | 42 | Invalid input (bad prompt, malformed request) |
| `:config_error` | 52 | Configuration error (invalid settings) |
| `:user_cancelled` | 130 | User cancelled the operation (Ctrl+C) |
| `:command_failed` | other | Generic command failure |
| `:command_timeout` | -- | Command exceeded the timeout |
| `:no_result` | -- | Stream ended without a result event |

On SSH-backed `execution_surface` values, Gemini is resolved on the remote
host. If the target shell cannot find `gemini`, the SDK returns
`:cli_not_found` with the remote stderr attached. If Gemini is installed
outside the remote non-login `PATH`, pass a remote command path through
`Options.cli_command`.

## Synchronous Error Handling

With `run/2`, errors are returned as `{:error, %Error{}}`:

```elixir
case GeminiCliSdk.run("Do something") do
  {:ok, text} ->
    IO.puts(text)

  {:error, %GeminiCliSdk.Error{kind: :auth_error, message: msg}} ->
    IO.puts(:stderr, "Authentication failed: #{msg}")
    IO.puts(:stderr, "Run: gemini auth login")

  {:error, %GeminiCliSdk.Error{kind: :cli_not_found}} ->
    IO.puts(:stderr, "Gemini CLI not found. Install it with: npm install -g @google/gemini-cli")

  {:error, %GeminiCliSdk.Error{kind: :command_timeout}} ->
    IO.puts(:stderr, "Request timed out. Try increasing timeout_ms.")

  {:error, %GeminiCliSdk.Error{} = error} ->
    IO.puts(:stderr, "Error: #{Exception.message(error)}")
end
```

## Streaming Error Handling

In streams, errors appear as `Types.ErrorEvent` structs:

```elixir
GeminiCliSdk.execute("Do something")
|> Enum.each(fn event ->
  case event do
    %GeminiCliSdk.Types.ErrorEvent{severity: "fatal", message: msg} ->
      IO.puts(:stderr, "Fatal error: #{msg}")

    %GeminiCliSdk.Types.ErrorEvent{severity: severity, message: msg} ->
      IO.puts(:stderr, "[#{severity}] #{msg}")

    %GeminiCliSdk.Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)

    _ ->
      :ok
  end
end)
```

### Error Events vs Result Events

The stream may contain both error events (mid-stream) and a final result event:

- `ErrorEvent` with `severity: "fatal"` indicates an unrecoverable error
- `ResultEvent` with `status: "error"` indicates the CLI finished with an error
- `ResultEvent` with `status: "success"` indicates success even if warnings occurred

## CLI Not Found

If the Gemini CLI is not installed, the SDK detects this before spawning:

```elixir
# Streaming: emits a single ErrorEvent
events = GeminiCliSdk.execute("hello") |> Enum.to_list()
# => [%Types.ErrorEvent{severity: "fatal", message: "..."}]

# Synchronous: returns {:error, %Error{}}
{:error, error} = GeminiCliSdk.run("hello")
```

## Timeouts

Timeout errors occur when the CLI doesn't respond within `timeout_ms`:

```elixir
opts = %GeminiCliSdk.Options{timeout_ms: 5_000}

# Streaming: the last event will be an ErrorEvent
events = GeminiCliSdk.execute("Complex task", opts) |> Enum.to_list()

# Synchronous: returns {:error, %Error{}}
{:error, %GeminiCliSdk.Error{}} = GeminiCliSdk.run("Complex task", opts)
```

## Raising on Errors

Since `GeminiCliSdk.Error` implements the `Exception` behaviour, you can raise it:

```elixir
case GeminiCliSdk.run("Do something") do
  {:ok, text} -> text
  {:error, error} -> raise error
end
```

## Retry Strategies

The SDK does not include built-in retries. Implement your own:

```elixir
defmodule MyApp.Gemini do
  def run_with_retry(prompt, opts \\ %GeminiCliSdk.Options{}, retries \\ 3) do
    case GeminiCliSdk.run(prompt, opts) do
      {:ok, _} = success ->
        success

      {:error, %GeminiCliSdk.Error{kind: :command_timeout}} when retries > 0 ->
        Process.sleep(1_000)
        run_with_retry(prompt, opts, retries - 1)

      {:error, _} = error ->
        error
    end
  end
end
```
