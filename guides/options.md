# Options Reference

The `GeminiCliSdk.Options` struct controls how the Gemini CLI is invoked. All fields have sensible defaults.

## Struct Fields

```elixir
%GeminiCliSdk.Options{
  model: nil,                      # Model name (e.g., "gemini-3.0-flash", "gemini-3.0-pro")
  yolo: false,                     # Skip all confirmation prompts
  approval_mode: nil,              # "auto-edit" | "full-auto" | nil
  sandbox: false,                  # Run in sandbox mode
  resume: nil,                     # Session ID to resume
  extensions: [],                  # List of extensions to enable
  include_directories: [],         # Directories to include in context (max 5)
  allowed_tools: [],               # Restrict to specific tools
  allowed_mcp_server_names: [],    # Restrict to specific MCP servers
  debug: false,                    # Enable debug output
  output_format: "stream-json",    # Output format (always "stream-json" for streaming)
  cwd: nil,                        # Working directory for the CLI
  env: %{},                        # Extra environment variables
  settings: nil,                   # Settings map (written to temp settings.json)
  system_prompt: nil,              # System prompt override
  timeout_ms: 300_000              # Timeout in milliseconds (default 5 minutes)
}
```

## Common Patterns

### Model Selection

```elixir
# Use a specific model
opts = %GeminiCliSdk.Options{model: "gemini-3.0-flash"}
{:ok, response} = GeminiCliSdk.run("Quick question", opts)
```

### Auto-Approval (YOLO Mode)

```elixir
# Skip all confirmation prompts
opts = %GeminiCliSdk.Options{yolo: true}
```

> **Note**: `yolo: true` and `approval_mode` are mutually exclusive. Setting both will raise an `ArgumentError` during validation.

### Approval Modes

```elixir
# Auto-approve file edits
opts = %GeminiCliSdk.Options{approval_mode: "auto-edit"}

# Full auto-approval
opts = %GeminiCliSdk.Options{approval_mode: "full-auto"}
```

### Sandbox Mode

```elixir
# Run in isolated sandbox
opts = %GeminiCliSdk.Options{sandbox: true}
```

### Working Directory

```elixir
# Run in a specific project directory
opts = %GeminiCliSdk.Options{cwd: "/path/to/project"}
```

### Environment Variables

```elixir
# Pass extra environment variables to the CLI
opts = %GeminiCliSdk.Options{
  env: %{
    "GEMINI_API_KEY" => "your-key-here",
    "GEMINI_MODEL" => "gemini-3.0-flash"
  }
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
# Only allow specific tools
opts = %GeminiCliSdk.Options{
  allowed_tools: ["read_file", "list_files"]
}
```

### Extensions

```elixir
# Enable CLI extensions
opts = %GeminiCliSdk.Options{
  extensions: ["@anthropic-ai/gemini-extension-code"]
}
```

### Custom Settings

```elixir
# Pass a settings map (written to a temporary settings.json)
opts = %GeminiCliSdk.Options{
  settings: %{
    "permissions" => %{
      "allow" => ["read_file", "write_file"]
    }
  }
}
```

### System Prompt

```elixir
# Override the system prompt
opts = %GeminiCliSdk.Options{
  system_prompt: "You are a helpful code reviewer. Be concise."
}
```

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
%GeminiCliSdk.Options{yolo: true, approval_mode: "auto-edit"}
|> GeminiCliSdk.Options.validate!()
```

## CLI Flag Mapping

| Option | CLI Flag |
|--------|----------|
| `model` | `--model` |
| `yolo` | `--yolo` |
| `approval_mode` | `--approval-mode` |
| `sandbox` | `--sandbox` |
| `resume` | `--resume` |
| `extensions` | `--extension` (repeated) |
| `include_directories` | `--include-directories` (comma-separated) |
| `allowed_tools` | `--allowed-tools` (comma-separated) |
| `allowed_mcp_server_names` | `--allowed-mcp-server-names` (comma-separated) |
| `debug` | `--debug` |
| `output_format` | `--output-format` |
| `system_prompt` | `--system-prompt` |
