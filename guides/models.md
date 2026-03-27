# Models

`GeminiCliSdk.Models` remains the convenience reader for Gemini model names, but
active model selection now resolves through `cli_subprocess_core`.

The authoritative mixed-input boundary is
`CliSubprocessCore.ModelInput.normalize/3`.

That means:

- `GeminiCliSdk.Options.validate!/1` treats explicit `model_payload` as
  authoritative
- raw `model` input is resolved through the shared core only when a payload was
  not already supplied
- repo-local `GEMINI_MODEL` env defaults are fallback inputs, not a second
  post-payload resolution path

## Available Models

The Gemini CLI supports these models:

| Model | Family | Description |
|-------|--------|-------------|
| `gemini-2.5-pro` | 2.5 (stable) | Most capable model for complex reasoning |
| `gemini-2.5-flash` | 2.5 (stable) | Fast, balanced model for most tasks |
| `gemini-2.5-flash-lite` | 2.5 (stable) | Fastest model for simple tasks |
| `gemini-3-pro-preview` | 3 (preview) | Next-gen pro model (requires preview features) |
| `gemini-3-flash-preview` | 3 (preview) | Next-gen flash model (requires preview features) |

## Built-in Defaults

| Function | Default Value | Description |
|----------|---------------|-------------|
| `Models.default_model/0` | `"gemini-2.5-pro"` | Most capable stable model |
| `Models.fast_model/0` | `"gemini-2.5-flash"` | Optimized for speed and cost |

```elixir
alias GeminiCliSdk.Models

# Use the default (most capable) model
opts = %GeminiCliSdk.Options{model: Models.default_model()}

# Use the fast model
opts = %GeminiCliSdk.Options{model: Models.fast_model()}

# List all built-in models
Models.available_models()
# => ["gemini-2.5-pro", "gemini-2.5-flash"]
```

## Aliases

Short aliases expand to full model names via `Models.resolve/1`:

```elixir
Models.resolve("pro")     # => "gemini-2.5-pro"
Models.resolve("flash")   # => "gemini-2.5-flash"
Models.resolve("default") # => "gemini-2.5-pro"
Models.resolve("fast")    # => "gemini-2.5-flash"

# Unknown names pass through unchanged
Models.resolve("gemini-3-pro-preview")
# => "gemini-3-pro-preview"
```

## Using Custom Models

The SDK does not restrict you to known models. Any non-empty string is accepted:

```elixir
# Use a preview model or any future model
opts = %GeminiCliSdk.Options{model: "gemini-3-flash-preview"}
{:ok, response} = GeminiCliSdk.run("Hello", opts)
```

This means you can use new models as soon as the Gemini CLI supports them,
without waiting for an SDK update.

## Validation

```elixir
Models.validate("gemini-2.5-pro")  # => :ok
Models.validate(nil)                # => :ok (uses CLI default)
Models.validate("")                 # => {:error, "Invalid model: ..."}
Models.validate(123)                # => {:error, "Invalid model: ..."}
```

## Checking Known Models

```elixir
Models.known?("gemini-2.5-pro")   # => true
Models.known?("flash")             # => true (it's an alias)
Models.known?("custom-model")      # => false
```

## Runtime Configuration

Override the default models via Application config without modifying SDK code:

```elixir
# config/config.exs
config :gemini_cli_sdk,
  default_model: "gemini-3-pro-preview",
  fast_model: "gemini-2.5-flash-lite"
```

After this configuration:

```elixir
Models.default_model()  # => "gemini-3-pro-preview"
Models.fast_model()     # => "gemini-2.5-flash-lite"
```

## Per-Environment Configuration

```elixir
# config/dev.exs
config :gemini_cli_sdk,
  default_model: "gemini-2.5-flash"  # Use cheaper model in development

# config/prod.exs
config :gemini_cli_sdk,
  default_model: "gemini-2.5-pro"    # Use most capable in production
```

## Best Practices

1. **Always reference `Models` instead of hardcoding strings** -- this keeps
   model names maintainable across your codebase.

2. **Use `Models.resolve/1` for user input** -- if your application accepts
   model names from users, pass them through `resolve/1` to support aliases.

3. **Use `Models.validate/1` at boundaries** -- validate model input from
   external sources (APIs, config files, user input) before passing to the SDK.

4. **Prefer `Models.fast_model/0` for low-latency tasks** -- interactive
   applications, quick lookups, and real-time features benefit from the
   faster model.
