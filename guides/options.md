# Options Reference

The `GeminiCliSdk.Options` struct controls how the Gemini CLI is invoked. All fields have sensible defaults.

## Struct Fields

```elixir
%GeminiCliSdk.Options{
  governed_authority: nil,           # Materialized authority for governed launch
  model_payload: nil,              # Shared core Selection (or a canonicalizable map form)
  model: nil,                      # Model name (e.g., Models.fast_model(), Models.default_model())
  cli_command: nil,                # Explicit gemini executable or command name
  yolo: false,                     # Skip all confirmation prompts
  approval_mode: nil,              # :default | :auto_edit | :yolo | :plan | nil
  sandbox: false,                  # Run in sandbox mode
  skip_trust: false,               # Emit Gemini CLI --skip-trust
  resume: nil,                     # true | session_id | nil
  extensions: [],                  # List of extensions to enable
  include_directories: [],         # Directories to include in context (max 5)
  allowed_tools: [],               # Restrict to specific tools
  allowed_mcp_server_names: [],    # Restrict to specific MCP servers
  debug: false,                    # Enable debug output
  output_format: "stream-json",    # Output format (always "stream-json" for streaming)
  cwd: nil,                        # Working directory for the CLI
  settings: nil,                   # Settings map written to a temp workspace
  system_prompt: nil,              # Prompt preamble prepended to --prompt
  timeout_ms: 300_000,             # Timeout in milliseconds (default 5 minutes)
  max_stderr_buffer_bytes: 65_536  # Max buffered stderr before truncation
}
```

`governed_authority` selects governed mode. When set, the SDK rejects
`cli_command`, `cwd`, settings-backed `.gemini` config roots, execution-surface
overrides, and model-payload env overrides. Standalone direct use keeps those
normal CLI/native-login controls when `governed_authority` is nil.

## Common Patterns

### Model Selection

```elixir
# Use a specific model
opts = %GeminiCliSdk.Options{model: GeminiCliSdk.Models.fast_model()}
{:ok, response} = GeminiCliSdk.run("Quick question", opts)
```

### Shared Core Model Payload

```elixir
{:ok, payload} =
  CliSubprocessCore.ModelRegistry.build_arg_payload(
    :gemini,
    GeminiCliSdk.Models.fast_model(),
    []
  )

opts = %GeminiCliSdk.Options{model_payload: payload}
{:ok, response} = GeminiCliSdk.run("Quick question", opts)
```

`GeminiCliSdk.Options.validate!/1` canonicalizes explicit payloads through the
shared core boundary. A real `CliSubprocessCore.ModelRegistry.Selection` is the
preferred form, but `Map.from_struct(payload)` is normalized back into the same
canonical selection while preserving forward-compatible extra fields.

### Auto-Approval (YOLO Mode)

```elixir
# Skip all confirmation prompts
opts = %GeminiCliSdk.Options{yolo: true}
```

> **Note**: `yolo: true` and `approval_mode` are mutually exclusive. Setting both will raise an `ArgumentError` during validation.

### Approval Modes

```elixir
# Auto-approve file edits
opts = %GeminiCliSdk.Options{approval_mode: :auto_edit}

# Full auto-approval
opts = %GeminiCliSdk.Options{approval_mode: :yolo}

# Backwards-compatible string aliases are still accepted at validation time
GeminiCliSdk.Options.validate!(%GeminiCliSdk.Options{approval_mode: "auto-edit"})
```

### Sandbox Mode

```elixir
# Run in isolated sandbox
opts = %GeminiCliSdk.Options{sandbox: true}
```

### Folder Trust

```elixir
# Trust the current runtime workspace for this headless CLI session
opts = %GeminiCliSdk.Options{skip_trust: true}
```

`skip_trust` maps to Gemini CLI's documented `--skip-trust` flag. It is useful
for headless SDK calls that run from temporary settings workspaces.

### Working Directory

```elixir
# Run in a specific project directory
opts = %GeminiCliSdk.Options{cwd: "/path/to/project"}
```

### Explicit CLI Command

```elixir
# Use a specific Gemini CLI executable in tests or custom installs
opts = %GeminiCliSdk.Options{
  cli_command: "/opt/gemini/bin/gemini"
}
```

### Include Directories

```elixir
# Include specific directories in context
opts = %GeminiCliSdk.Options{
  include_directories: ["/path/to/src", "/path/to/docs"]
}
```

> **Note**: Maximum of 5 directories allowed.

### Tool Restrictions

```elixir
# Forward Gemini CLI's approval-bypass allow-list flag
opts = %GeminiCliSdk.Options{
  allowed_tools: ["read_file", "list_files"]
}
```

`allowed_tools` maps to Gemini CLI's `--allowed-tools` flag. It is not a
no-tool mode. Use `GeminiCliSdk.SettingsProfiles.plain_response/0` when the goal
is a plain response profile with model-visible tools disabled through settings.

### Extensions

```elixir
# Enable CLI extensions
opts = %GeminiCliSdk.Options{
  extensions: ["my-gemini-extension"]
}
```

### Custom Settings

```elixir
# Pass a settings map written to a temporary runtime workspace
opts = %GeminiCliSdk.Options{
  settings: %{
    "permissions" => %{
      "allow" => ["read_file", "write_file"]
    }
  }
}
```

When `settings` is present, the SDK writes `.gemini/settings.json` under a
temporary runtime workspace and runs Gemini from that workspace. The original
working directory is added to `include_directories` for local sessions so the
CLI still has project context when tools are enabled.

### Plain Response Profile

```elixir
opts = %GeminiCliSdk.Options{
  extensions: ["none"],
  settings: GeminiCliSdk.SettingsProfiles.plain_response(),
  skip_trust: true,
  system_prompt: "Answer directly and do not discuss tools or files."
}
```

### System Prompt

```elixir
# Prepend instruction text to the noninteractive prompt
opts = %GeminiCliSdk.Options{
  system_prompt: "You are a helpful code reviewer. Be concise."
}
```

Gemini CLI does not expose a proven no-env system-prompt override flag in the
vendored source. The SDK therefore prepends `system_prompt` to the prompt text
passed through `--prompt`; it does not use Gemini CLI's template-file override.

### Timeout

```elixir
# Short timeout for quick queries
opts = %GeminiCliSdk.Options{timeout_ms: 30_000}

# Long timeout for complex tasks
opts = %GeminiCliSdk.Options{timeout_ms: 600_000}
```

## Validation

Options are validated when passed to `execute/2` or `run/2`. Invalid combinations raise `ArgumentError`:

```elixir
# This raises ArgumentError -- yolo and approval_mode conflict
%GeminiCliSdk.Options{yolo: true, approval_mode: :auto_edit}
|> GeminiCliSdk.Options.validate!()
```

## CLI Flag Mapping

| Option | CLI Flag |
|--------|----------|
| `model` | `--model` |
| `yolo` | `--yolo` |
| `approval_mode` | `--approval-mode` |
| `sandbox` | `--sandbox` |
| `skip_trust` | `--skip-trust` |
| `resume` | `--resume` |
| `extensions` | `--extensions` (repeated) |
| `include_directories` | `--include-directories` (comma-separated) |
| `allowed_tools` | `--allowed-tools` (comma-separated) |
| `allowed_mcp_server_names` | `--allowed-mcp-server-names` (comma-separated) |
| `debug` | `--debug` |
| `output_format` | `--output-format` |
| `system_prompt` | prepended into `--prompt` text |
