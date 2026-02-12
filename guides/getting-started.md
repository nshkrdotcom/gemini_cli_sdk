# Getting Started

## Prerequisites

1. **Elixir** >= 1.14
2. **Gemini CLI** installed and authenticated:

```bash
# Install the Gemini CLI
npm install -g @anthropic-ai/gemini

# Authenticate
gemini auth login
```

3. **erlexec** requires a C compiler for its NIF. On Debian/Ubuntu:

```bash
sudo apt install build-essential
```

## Installation

Add `gemini_cli_sdk` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gemini_cli_sdk, "~> 0.1.0"}
  ]
end
```

Then fetch and compile:

```bash
mix deps.get
mix compile
```

## Quick Start

### Streaming (recommended)

The streaming API returns a lazy `Stream` that yields typed event structs as the Gemini CLI produces output:

```elixir
GeminiCliSdk.execute("Explain GenServer in 3 sentences")
|> Enum.each(fn event ->
  case event do
    %GeminiCliSdk.Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)
    _ ->
      :ok
  end
end)
```

### Synchronous

For simple request/response usage:

```elixir
{:ok, response} = GeminiCliSdk.run("What is Elixir?")
IO.puts(response)
```

### With Options

```elixir
opts = %GeminiCliSdk.Options{
  model: "gemini-3.0-flash",
  timeout_ms: 60_000
}

{:ok, response} = GeminiCliSdk.run("Summarize OTP", opts)
```

## How It Works

GeminiCliSdk spawns the `gemini` CLI as a subprocess using [erlexec](https://hex.pm/packages/erlexec), which provides:

- Process group management (proper cleanup on halt)
- Separate stdin/stdout/stderr streams
- Signal delivery (SIGTERM, SIGKILL)
- Non-blocking async I/O

The CLI is invoked with `--output-format stream-json`, which emits newline-delimited JSON (JSONL). Each line is parsed into a typed Elixir struct. The stream is lazy and composable with all standard `Stream` and `Enum` functions.

## Next Steps

- [Streaming Guide](streaming.md) -- Deep dive into the streaming API
- [Options Reference](options.md) -- All available configuration options
- [Error Handling](error-handling.md) -- Handling errors gracefully
- [Session Management](sessions.md) -- Resume and manage conversations
