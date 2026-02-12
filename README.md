<p align="center">
  <img src="assets/gemini_cli_sdk.svg" alt="GeminiCliSdk" width="200"/>
</p>

<p align="center">
  <a href="https://hex.pm/packages/gemini_cli_sdk"><img src="https://img.shields.io/hexpm/v/gemini_cli_sdk.svg" alt="Hex.pm Version"/></a>
  <a href="https://hexdocs.pm/gemini_cli_sdk"><img src="https://img.shields.io/badge/hex-docs-blue.svg" alt="HexDocs"/></a>
  <a href="https://github.com/nshkrdotcom/gemini_cli_sdk/actions"><img src="https://github.com/nshkrdotcom/gemini_cli_sdk/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
  <a href="https://hex.pm/packages/gemini_cli_sdk"><img src="https://img.shields.io/hexpm/l/gemini_cli_sdk.svg" alt="License"/></a>
  <a href="https://hex.pm/packages/gemini_cli_sdk"><img src="https://img.shields.io/hexpm/dt/gemini_cli_sdk.svg" alt="Downloads"/></a>
</p>

# GeminiCliSdk

An Elixir SDK for the [Gemini CLI](https://github.com/anthropics/gemini) -- build AI-powered applications with Google Gemini through a robust, idiomatic wrapper around the Gemini command-line interface.

## Features

- **Streaming** -- Lazy `Stream`-based API with typed event structs and backpressure
- **Synchronous** -- Simple `{:ok, text} | {:error, error}` for request/response patterns
- **Session Management** -- List, resume, and delete conversation sessions
- **Subprocess Safety** -- Built on [erlexec](https://hex.pm/packages/erlexec) with process groups, signal delivery, and guaranteed cleanup
- **Typed Events** -- 6 event types (init, message, tool_use, tool_result, error, result) parsed from JSONL
- **Full Options** -- Model selection, YOLO mode, sandboxing, extensions, tool restrictions, and more
- **OTP Integration** -- Application supervision tree with TaskSupervisor for async I/O

## Installation

Add `gemini_cli_sdk` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gemini_cli_sdk, "~> 0.1.0"}
  ]
end
```

**Prerequisites**: The [Gemini CLI](https://github.com/anthropics/gemini) must be installed and authenticated.

## Quick Start

### Streaming

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

```elixir
{:ok, response} = GeminiCliSdk.run("What is Elixir?")
IO.puts(response)
```

### With Options

```elixir
opts = %GeminiCliSdk.Options{
  model: "gemini-2.5-flash",
  yolo: true,
  timeout_ms: 60_000
}

{:ok, response} = GeminiCliSdk.run("Refactor this function", opts)
```

### Sessions

```elixir
# List sessions
{:ok, sessions} = GeminiCliSdk.list_sessions()

# Resume a session
GeminiCliSdk.resume_session("abc123", %GeminiCliSdk.Options{}, "Continue")
|> Enum.each(fn event ->
  case event do
    %GeminiCliSdk.Types.MessageEvent{role: "assistant", content: text} ->
      IO.write(text)
    _ -> :ok
  end
end)
```

## Event Types

| Struct | Description |
|--------|-------------|
| `Types.InitEvent` | Session initialized with `session_id` and `model` |
| `Types.MessageEvent` | Message chunk with `role` and `content` |
| `Types.ToolUseEvent` | Tool invocation with `name` and `input` |
| `Types.ToolResultEvent` | Tool result with `name` and `output` |
| `Types.ErrorEvent` | Error with `severity` and `message` |
| `Types.ResultEvent` | Final result with `status` and `stats` |

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/gemini_cli_sdk).

- [Getting Started](https://hexdocs.pm/gemini_cli_sdk/getting-started.html)
- [Streaming Guide](https://hexdocs.pm/gemini_cli_sdk/streaming.html)
- [Options Reference](https://hexdocs.pm/gemini_cli_sdk/options.html)
- [Error Handling](https://hexdocs.pm/gemini_cli_sdk/error-handling.html)
- [Architecture](https://hexdocs.pm/gemini_cli_sdk/architecture.html)

## Examples

See the [`examples/`](examples/) directory for live examples that run against the real Gemini CLI:

```bash
mix run examples/simple_prompt.exs
mix run examples/streaming.exs
bash examples/run_all.sh
```

## License

MIT License. See [LICENSE](LICENSE) for details.
