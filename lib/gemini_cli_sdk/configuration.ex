defmodule GeminiCliSdk.Configuration do
  @moduledoc """
  Centralized numeric constants and compatibility defaults.

  After the common runtime replatform, Gemini's streaming/session lane runs on
  `cli_subprocess_core`. This module therefore keeps Gemini-owned defaults for
  stream lifecycle management, synchronous command execution, public option
  defaults, and preserved compatibility knobs.

  Override any value via Application configuration:

      # config/config.exs
      config :gemini_cli_sdk,
        stream_timeout_ms: 600_000,
        max_buffer_size: 2_097_152

  ## Timeouts

  | Key | Default | Used By | Description |
  |-----|---------|---------|-------------|
  | `:command_timeout_ms` | 60,000 | `Command` | Synchronous command timeout |
  | `:stream_timeout_ms` | 300,000 | `Stream` | Stream receive timeout |
  | `:default_timeout_ms` | 300,000 | `Options` | Default user-facing timeout |
  | `:transport_call_timeout_ms` | 5,000 | Legacy compatibility docs | Preserved legacy timeout |
  | `:transport_force_close_timeout_ms` | 500 | Legacy compatibility docs | Preserved legacy timeout |
  | `:transport_headless_timeout_ms` | 5,000 | Legacy compatibility docs | Preserved legacy timeout |
  | `:transport_close_grace_ms` | 2,000 | `Stream` | Close grace period |
  | `:transport_kill_grace_ms` | 250 | `Stream` | Kill/demonitor grace period |
  | `:command_stop_wait_ms` | 200 | `Command` | Wait after SIGTERM |
  | `:command_kill_wait_ms` | 500 | `Command` | Wait after SIGKILL |
  | `:finalize_delay_ms` | 25 | Legacy compatibility docs | Preserved legacy delay |

  ## Buffer Sizes

  | Key | Default | Used By | Description |
  |-----|---------|---------|-------------|
  | `:max_buffer_size` | 1,048,576 | Legacy compatibility docs | Preserved legacy stdout buffer (1 MB) |
  | `:max_stderr_buffer_size` | 262,144 | `Options`, `Stream` | Default stderr buffer (256 KB) |

  ## Limits

  | Key | Default | Used By | Description |
  |-----|---------|---------|-------------|
  | `:max_lines_per_batch` | 200 | Legacy compatibility docs | Preserved legacy batch size |
  | `:max_include_directories` | 5 | `Options` | Max include directories |

  ## Compile-Time vs Runtime

  Constants consumed via module attributes (for example in `Stream`) are
  evaluated at compile time. Changing these via `Application.put_env/3` at
  runtime requires recompilation of the consuming module. Constants consumed via
  direct function calls (for example in `Command.run/2`) pick up runtime
  changes immediately.
  """

  @defaults [
    # Timeouts
    command_timeout_ms: 60_000,
    stream_timeout_ms: 300_000,
    default_timeout_ms: 300_000,
    transport_call_timeout_ms: 5_000,
    transport_force_close_timeout_ms: 500,
    transport_headless_timeout_ms: 5_000,
    transport_close_grace_ms: 2_000,
    transport_kill_grace_ms: 250,
    command_stop_wait_ms: 200,
    command_kill_wait_ms: 500,
    finalize_delay_ms: 25,
    # Buffer sizes
    max_buffer_size: 1_048_576,
    max_stderr_buffer_size: 262_144,
    # Limits
    max_lines_per_batch: 200,
    max_include_directories: 5
  ]

  for {key, default} <- @defaults do
    @doc "Returns the configured value for `#{key}` (default: `#{default}`)."
    @spec unquote(key)() :: pos_integer()
    def unquote(key)() do
      Application.get_env(:gemini_cli_sdk, unquote(key), unquote(default))
    end
  end

  @doc "Returns all configuration keys and their current values."
  @spec all() :: keyword(pos_integer())
  def all do
    Enum.map(@defaults, fn {key, _default} ->
      {key, apply(__MODULE__, key, [])}
    end)
  end
end
