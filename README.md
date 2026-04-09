<p align="center">
  <img src="assets/gemini_cli_sdk.svg" alt="GeminiCliSdk" width="200"/>
</p>

<p align="center">
  <a href="https://hex.pm/packages/gemini_cli_sdk"><img src="https://img.shields.io/hexpm/v/gemini_cli_sdk.svg" alt="Hex.pm Version"/></a>
  <a href="https://hexdocs.pm/gemini_cli_sdk"><img src="https://img.shields.io/badge/hex-docs-blue.svg" alt="HexDocs"/></a>
  <a href="https://hex.pm/packages/gemini_cli_sdk"><img src="https://img.shields.io/hexpm/l/gemini_cli_sdk.svg" alt="License"/></a>
  <a href="https://hex.pm/packages/gemini_cli_sdk"><img src="https://img.shields.io/hexpm/dt/gemini_cli_sdk.svg" alt="Downloads"/></a>
</p>

# GeminiCliSdk

An Elixir SDK for the [Gemini CLI](https://github.com/google-gemini/gemini-cli) -- build AI-powered applications with Google Gemini through a robust, idiomatic wrapper around the Gemini command-line interface.

## Documentation Menu

- `README.md` - installation, quick start, and runtime boundaries
- `guides/getting-started.md` - first execution and session flows
- `guides/options.md` - runtime and CLI option shaping
- `guides/models.md` - Gemini model selection behavior
- `guides/architecture.md` - shared core runtime ownership
- `guides/testing.md` - local validation workflow

## Features

- **Streaming** -- Lazy `Stream`-based API with typed event structs and backpressure
- **Synchronous** -- Simple `{:ok, text} | {:error, error}` for request/response patterns
- **Session Management** -- List, resume, and delete conversation sessions
- **Shared Core Runtime** -- Streaming and one-shot command execution now run on `cli_subprocess_core` while preserving Gemini-specific public types and entrypoints
- **Subprocess Safety** -- Built on `cli_subprocess_core`, which now routes the covered local session lane through `ExecutionPlane.Process.Transport` while keeping Gemini-facing types and cleanup semantics stable
- **Typed Events** -- 6 event types (init, message, tool_use, tool_result, error, result) parsed from JSONL
- **Full Options** -- Model selection, YOLO mode, sandboxing, extensions, tool restrictions, and more
- **OTP Integration** -- Application supervision tree with TaskSupervisor for async I/O

## Installation

Add `gemini_cli_sdk` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gemini_cli_sdk, "~> 0.2.0"}
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

All stream-event structs are now schema-backed. Known fields are normalized
through `Zoi`, forward-compatible unknown fields are preserved in `extra`, and
the event modules expose `to_map/1` for projection back to wire shape.

## Architecture

GeminiCliSdk preserves its public API while running the common CLI session lane on
`cli_subprocess_core`.

The current layering is:

```text
GeminiCliSdk public API
  -> GeminiCliSdk.Stream / GeminiCliSdk.Runtime.CLI
  -> CliSubprocessCore.Session
  -> ExecutionPlane.Process.Transport
  -> gemini CLI

GeminiCliSdk command helpers
  -> CliSubprocessCore.Command.run/2
  -> ExecutionPlane.Process (local) / ExternalRuntimeTransport.Transport (non-local)
  -> gemini CLI
```

`GeminiCliSdk.Runtime.CLI` is the Gemini runtime kit. It starts
core sessions, preserves Gemini CLI command resolution and option shaping, and
projects normalized core events back into `GeminiCliSdk.Types.*`.

No Gemini-owned raw transport module remains for the covered lane. The SDK keeps
Gemini-specific command resolution, option shaping, and event projection above
the shared core and Execution Plane-backed lower transport seam.

## Ownership Boundary

The Wave 6 boundary for Gemini is:

- shared session lifecycle
- shared JSONL parsing and normalized event flow
- shared local session transport ownership through `ExecutionPlane.Process.Transport`
- shared command execution through `CliSubprocessCore.Command`, with local one-shot
  execution routed through `ExecutionPlane.Process` and non-local execution
  staying on the external transport substrate

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
and typed event/result projection above the shared core.

The release and composition model is:

- the common Gemini profile stays built into `cli_subprocess_core`
- `gemini_cli_sdk` remains the provider-specific runtime-kit package above that
  shared core
- no extra ASM extension seam is introduced unless Gemini later proves a real
  richer provider-native surface beyond the current common lane

If `gemini_cli_sdk` is installed alongside `agent_session_manager`, ASM
reports Gemini runtime availability in
`ASM.Extensions.ProviderSDK.capability_report/0` but keeps
`namespaces: []` because Gemini currently composes through the common ASM
surface only.

## Centralized Model Selection

`gemini_cli_sdk` now consumes model payloads resolved by
`cli_subprocess_core`. The SDK no longer owns active fallback/defaulting
policy for provider selection.

Authoritative policy surface:

- `CliSubprocessCore.ModelRegistry.resolve/3`
- `CliSubprocessCore.ModelRegistry.validate/2`
- `CliSubprocessCore.ModelRegistry.default_model/2`
- `CliSubprocessCore.ModelRegistry.build_arg_payload/3`
- `CliSubprocessCore.ModelInput.normalize/3`

Gemini-side responsibility is limited to:

- carrying the resolved `model_payload` on `GeminiCliSdk.Options`
- projecting the resolved model for UX and metadata
- rendering `--model` only when the resolved value is non-empty
- treating repo-local env defaults as fallback inputs only when no explicit
  payload was supplied

No repo-local Gemini model fallback remains.

`GeminiCliSdk.Options.validate!/1` canonicalizes explicit payloads through the
shared core boundary. A `CliSubprocessCore.ModelRegistry.Selection` is the
preferred form, and `Map.from_struct(selection)` is normalized back into the
same canonical payload when callers already have a serialized struct map.

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

## Model Selection Contract

See [Centralized Model Selection](#centralized-model-selection). The Gemini SDK
renders provider transport args from the shared resolved payload and does not
emit nil/null/blank model values.
## Session Listing And Resume Surfaces

Gemini now exposes a typed session-history projection for orchestration layers that need to recover
an existing CLI conversation instead of replaying prompts from scratch.

- `GeminiCliSdk.list_session_entries/1` parses the CLI session list into typed
  `%GeminiCliSdk.Session.Entry{}` values
- `GeminiCliSdk.Runtime.CLI.capabilities/0` publishes `:session_history`, `:session_resume`,
  `:session_pause`, and `:session_intervene`
- `GeminiCliSdk.Runtime.CLI.list_provider_sessions/1` projects those typed entries into the common
  runtime-neutral list shape used by higher layers

The runtime also now carries `system_prompt` through the validated options surface so the caller can
resume with the same instruction context it started with.
