# Models

The `GeminiCliSdk.Models` module is the single source of truth for model names
throughout the SDK. It provides built-in defaults, aliases, validation, and
runtime configuration.

## Built-in Models

| Function | Default Value | Description |
|----------|---------------|-------------|
| `Models.default_model/0` | `"gemini-3.0-pro"` | Most capable model |
| `Models.fast_model/0` | `"gemini-3.0-flash"` | Optimized for speed and cost |

```elixir
alias GeminiCliSdk.Models

# Use the default (most capable) model
opts = %GeminiCliSdk.Options{model: Models.default_model()}

# Use the fast model
opts = %GeminiCliSdk.Options{model: Models.fast_model()}

# List all built-in models
Models.available_models()
# => ["gemini-3.0-pro", "gemini-3.0-flash"]
```

## Aliases

Short aliases expand to full model names via `Models.resolve/1`:

```elixir
Models.resolve("pro")     # => "gemini-3.0-pro"
Models.resolve("flash")   # => "gemini-3.0-flash"
Models.resolve("default") # => "gemini-3.0-pro"
Models.resolve("fast")    # => "gemini-3.0-flash"

# Unknown names pass through unchanged
Models.resolve("gemini-3.0-pro-experimental")
# => "gemini-3.0-pro-experimental"
```

## Using Custom Models

The SDK does not restrict you to known models. Any non-empty string is accepted:

```elixir
# Use a model not yet in the SDK's built-in list
opts = %GeminiCliSdk.Options{model: "gemini-3.0-pro-experimental"}
{:ok, response} = GeminiCliSdk.run("Hello", opts)
```

This means you can use new models as soon as the Gemini CLI supports them,
without waiting for an SDK update.

## Validation

```elixir
Models.validate("gemini-3.0-pro")  # => :ok
Models.validate(nil)                # => :ok (uses CLI default)
Models.validate("")                 # => {:error, "Invalid model: ..."}
Models.validate(123)                # => {:error, "Invalid model: ..."}
```

## Checking Known Models

```elixir
Models.known?("gemini-3.0-pro")   # => true
Models.known?("flash")             # => true (it's an alias)
Models.known?("custom-model")      # => false
```

## Runtime Configuration

Override the default models via Application config without modifying SDK code:

```elixir
# config/config.exs
config :gemini_cli_sdk,
  default_model: "gemini-3.0-pro-experimental",
  fast_model: "gemini-3.0-flash-lite"
```

After this configuration:

```elixir
Models.default_model()  # => "gemini-3.0-pro-experimental"
Models.fast_model()     # => "gemini-3.0-flash-lite"
```

## Per-Environment Configuration

```elixir
# config/dev.exs
config :gemini_cli_sdk,
  default_model: "gemini-3.0-flash"  # Use cheaper model in development

# config/prod.exs
config :gemini_cli_sdk,
  default_model: "gemini-3.0-pro"    # Use most capable in production
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
