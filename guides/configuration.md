# Configuration

The `GeminiCliSdk.Configuration` module centralizes all numeric constants --
timeouts, buffer sizes, batch limits, and delays -- used by the SDK's internal
modules. Every value can be overridden via Application configuration.

## All Configuration Keys

### Timeouts

| Key | Default | Used By | Description |
|-----|---------|---------|-------------|
| `:command_timeout_ms` | 60,000 | `Command` | Synchronous command timeout |
| `:stream_timeout_ms` | 300,000 | `Stream` | Stream receive timeout |
| `:default_timeout_ms` | 300,000 | `Options` | Default user-facing timeout |
| `:transport_call_timeout_ms` | 5,000 | `Transport.Erlexec` | GenServer call timeout |
| `:transport_force_close_timeout_ms` | 500 | `Transport.Erlexec` | Force-close timeout |
| `:transport_headless_timeout_ms` | 5,000 | `Transport.Erlexec` | No-subscriber auto-stop |
| `:transport_close_grace_ms` | 2,000 | `Stream` | Close grace period |
| `:transport_kill_grace_ms` | 250 | `Stream` | Kill/demonitor grace period |
| `:command_stop_wait_ms` | 200 | `Command` | Wait after SIGTERM |
| `:command_kill_wait_ms` | 500 | `Command` | Wait after SIGKILL |
| `:finalize_delay_ms` | 25 | `Transport.Erlexec` | Exit finalization delay |

### Buffer Sizes

| Key | Default | Used By | Description |
|-----|---------|---------|-------------|
| `:max_buffer_size` | 1,048,576 (1 MB) | `Transport.Erlexec` | Max stdout buffer |
| `:max_stderr_buffer_size` | 262,144 (256 KB) | `Transport.Erlexec` | Max stderr ring buffer |

### Limits

| Key | Default | Used By | Description |
|-----|---------|---------|-------------|
| `:max_lines_per_batch` | 200 | `Transport.Erlexec` | Stdout drain batch size |
| `:max_include_directories` | 5 | `Options` | Max include directories |

## Overriding Configuration

Add entries to your `config/config.exs`:

```elixir
config :gemini_cli_sdk,
  stream_timeout_ms: 600_000,        # 10 minutes for long tasks
  max_buffer_size: 2_097_152,         # 2 MB stdout buffer
  command_timeout_ms: 120_000         # 2 minute sync timeout
```

## Per-Environment Configuration

```elixir
# config/dev.exs
config :gemini_cli_sdk,
  stream_timeout_ms: 60_000           # Short timeout in dev

# config/prod.exs
config :gemini_cli_sdk,
  stream_timeout_ms: 600_000          # Generous timeout in prod
```

## Inspecting Current Values

```elixir
alias GeminiCliSdk.Configuration

# Individual values
Configuration.stream_timeout_ms()      # => 300_000
Configuration.max_buffer_size()        # => 1_048_576

# All values at once
Configuration.all()
# => [command_timeout_ms: 60000, stream_timeout_ms: 300000, ...]
```

## Compile-Time vs Runtime

Some modules consume Configuration values at **compile time** via module
attributes for performance in hot paths:

```elixir
# In Transport.Erlexec (evaluated once at compile time):
@max_lines_per_batch Configuration.max_lines_per_batch()
```

Others consume values at **runtime** for maximum flexibility:

```elixir
# In Command.run/2 (evaluated each call):
timeout = Configuration.command_timeout_ms()
```

**What this means:**

- Values used via `Application.get_env/3` at runtime (in `Command`,
  `Options.validate!/1`) respond to config changes immediately.
- Values captured in module attributes (`Transport.Erlexec`, `Stream`) require
  recompilation (`mix compile --force`) to pick up new values.
- The `Options` struct default (`timeout_ms: 300_000`) is set at compile time.
  To use a runtime-configured default, construct the struct explicitly:
  `%Options{timeout_ms: Configuration.default_timeout_ms()}`.

## Tuning Guide

### For Long-Running Tasks

```elixir
config :gemini_cli_sdk,
  stream_timeout_ms: 900_000,         # 15 minutes
  default_timeout_ms: 900_000
```

### For High-Throughput Streaming

```elixir
config :gemini_cli_sdk,
  max_buffer_size: 4_194_304,         # 4 MB stdout buffer
  max_lines_per_batch: 500            # Larger drain batches
```

### For Resource-Constrained Environments

```elixir
config :gemini_cli_sdk,
  max_buffer_size: 524_288,           # 512 KB stdout buffer
  max_stderr_buffer_size: 65_536,     # 64 KB stderr buffer
  max_lines_per_batch: 50
```
