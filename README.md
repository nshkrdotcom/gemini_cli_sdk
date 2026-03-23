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

An Elixir SDK for the [Gemini CLI](https://github.com/google-gemini/gemini-cli) -- build AI-powered applications with Google Gemini through a robust, idiomatic wrapper around the Gemini command-line interface.

## Features

- **Streaming** -- Lazy `Stream`-based API with typed event structs and backpressure
- **Synchronous** -- Simple `{:ok, text} | {:error, error}` for request/response patterns
- **Session Management** -- List, resume, and delete conversation sessions
- **Shared Core Runtime** -- Streaming and one-shot command execution now run on `cli_subprocess_core` while preserving Gemini-specific public types and entrypoints
- **Subprocess Safety** -- Built on `cli_subprocess_core`, which owns the shared `erlexec` transport for cleanup and raw process control
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

**Prerequisites**: The [Gemini CLI](https://github.com/google-gemini/gemini-cli) must be installed and authenticated.

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
  model: GeminiCliSdk.Models.fast_model(),
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
| `Types.ToolUseEvent` | Tool invocation with `tool_name` and `parameters` |
| `Types.ToolResultEvent` | Tool result with `tool_id` and `output` |
| `Types.ErrorEvent` | Error with `severity` and `message` |
| `Types.ResultEvent` | Final result with `status` and `stats` |

## Architecture

GeminiCliSdk preserves its public API while running the common CLI session lane on
`cli_subprocess_core`.

The current layering is:

```text
GeminiCliSdk public API
  -> GeminiCliSdk.Stream / GeminiCliSdk.Runtime.CLI
  -> CliSubprocessCore.Session
  -> CliSubprocessCore raw transport
  -> gemini CLI

GeminiCliSdk command helpers
  -> CliSubprocessCore.Command.run/2
  -> CliSubprocessCore raw transport
  -> gemini CLI
```

`GeminiCliSdk.Runtime.CLI` is the Gemini runtime kit. It starts
core sessions, preserves Gemini CLI command resolution and option shaping, and
projects normalized core events back into `GeminiCliSdk.Types.*`.

The preserved `GeminiCliSdk.Transport` modules are public Gemini entrypoints
backed by the core raw transport layer instead of owning a separate subprocess
runtime.

## Ownership Boundary

Phase 2A completed the Gemini ownership cut by moving the common Gemini CLI
runtime family into `cli_subprocess_core`:

- shared session lifecycle
- shared JSONL parsing and normalized event flow
- shared raw `erlexec` transport ownership
- shared non-PTY command execution for session management and version helpers

Public Gemini entrypoints stay the same:

- `GeminiCliSdk.execute/2`
- `GeminiCliSdk.run/2`
- `GeminiCliSdk.resume_session/3`
- `GeminiCliSdk.list_sessions/1`
- `GeminiCliSdk.delete_session/2`

Gemini CLI resolution, option shaping, and public result/error mapping remain in
this repo above the shared core.

No separate Gemini-owned common subprocess runtime remains here. Repo-local
ownership is limited to Gemini CLI discovery, argument and environment shaping,
typed event/result projection, and the public Gemini transport surface above
the shared core.

Phase 2B keeps Gemini on the simple packaging path:

- the common Gemini profile stays built into `cli_subprocess_core`
- `gemini_cli_sdk` remains the thin provider-specific runtime-kit package above
  that shared core
- no extra ASM extension seam is introduced unless Gemini later proves a real
  richer provider-native surface beyond the current common lane

If `gemini_cli_sdk` is installed alongside `agent_session_manager`, ASM
reports Gemini runtime availability in
`ASM.Extensions.ProviderSDK.capability_report/0` but keeps
`namespaces: []` because Gemini currently composes through the common ASM
surface only.

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/gemini_cli_sdk).

- [Getting Started](https://hexdocs.pm/gemini_cli_sdk/getting-started.html)
- [Streaming Guide](https://hexdocs.pm/gemini_cli_sdk/streaming.html)
- [Options Reference](https://hexdocs.pm/gemini_cli_sdk/options.html)
- [Error Handling](https://hexdocs.pm/gemini_cli_sdk/error-handling.html)
- [Architecture](https://hexdocs.pm/gemini_cli_sdk/architecture.html)

## Examples

See the `examples/` directory for live examples that run against the real Gemini CLI:

```bash
mix run examples/simple_prompt.exs
mix run examples/streaming.exs
bash examples/run_all.sh
```

## License

MIT License. See [LICENSE](LICENSE) for details.
