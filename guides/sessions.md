# Session Management

The Gemini CLI maintains conversation sessions per project. GeminiCliSdk provides functions to list, resume, and delete sessions.

## Listing Sessions

```elixir
{:ok, output} = GeminiCliSdk.list_sessions()
IO.puts(output)
```

This runs `gemini --list-sessions` and returns the raw text output, which typically looks like:

```
Available sessions for this project (3):
  1. Fix authentication bug (2 days ago) [abc123]
  2. Add pagination (5 hours ago) [def456]
  3. Refactor tests (10 minutes ago) [ghi789]
```

## Resuming a Session

Resume a previous session and continue the conversation with streaming events:

```elixir
# Resume by session ID
GeminiCliSdk.resume_session("abc123")
|> Enum.each(fn event ->
  case event do
    %GeminiCliSdk.Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)
    _ ->
      :ok
  end
end)
```

### Resume with a New Prompt

You can provide a follow-up prompt when resuming:

```elixir
GeminiCliSdk.resume_session("abc123", %GeminiCliSdk.Options{}, "Now add error handling")
|> Enum.each(fn event ->
  case event do
    %GeminiCliSdk.Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)
    _ ->
      :ok
  end
end)
```

### Resume with Options

```elixir
opts = %GeminiCliSdk.Options{
  model: "gemini-2.5-flash",
  timeout_ms: 120_000
}

GeminiCliSdk.resume_session("latest", opts, "Continue where we left off")
|> Enum.to_list()
```

## Deleting a Session

Delete a session by its index number or ID:

```elixir
# Delete by index
{:ok, _} = GeminiCliSdk.delete_session("2")

# Delete by session ID
{:ok, _} = GeminiCliSdk.delete_session("abc123")
```

## Session Workflow Example

```elixir
# 1. List available sessions
{:ok, sessions} = GeminiCliSdk.list_sessions()
IO.puts(sessions)

# 2. Resume the most recent session with a follow-up
GeminiCliSdk.resume_session("latest", %GeminiCliSdk.Options{}, "What were we working on?")
|> Enum.each(fn
  %GeminiCliSdk.Types.MessageEvent{role: "assistant", content: text} ->
    IO.write(text)
  _ ->
    :ok
end)

# 3. Clean up old sessions
{:ok, _} = GeminiCliSdk.delete_session("1")
```
