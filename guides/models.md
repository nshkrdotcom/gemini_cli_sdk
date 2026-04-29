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

The shared core registry allows these Gemini CLI model values:

| Model | Family | Description |
|-------|--------|-------------|
| `auto-gemini-3` | CLI virtual | Gemini CLI automatic routing for Gemini 3 models |
| `auto-gemini-2.5` | CLI virtual | Gemini CLI automatic routing for Gemini 2.5 models |
| `pro` | CLI alias | Gemini CLI pro alias |
| `flash` | CLI alias | Gemini CLI flash alias |
| `flash-lite` | CLI alias | Gemini CLI flash-lite alias |
| `gemini-3.1-pro-preview` | 3.1 preview | Gemini 3.1 pro preview model |
| `gemini-3-flash-preview` | 3 preview | Gemini 3 flash preview model |
| `gemini-3.1-flash-lite-preview` | 3.1 preview | Gemini 3.1 flash-lite preview model |
| `gemini-2.5-pro` | 2.5 stable | Gemini 2.5 pro model |
| `gemini-2.5-flash` | 2.5 stable | Gemini 2.5 flash model |
| `gemini-2.5-flash-lite` | 2.5 stable | Gemini 2.5 flash-lite model |

The `auto-*`, `pro`, `flash`, and `flash-lite` values are passed through as
Gemini CLI model values. They are not resolved by this SDK into concrete API
model ids.

## Built-in Defaults

| Function | Default Value | Description |
|----------|---------------|-------------|
| `Models.default_model/0` | `"auto-gemini-3"` | Gemini CLI automatic Gemini 3 routing |
| `Models.fast_model/0` | `"gemini-3.1-flash-lite-preview"` | Optimized for speed and cost |

```elixir
alias GeminiCliSdk.Models

# Use the default (most capable) model
opts = %GeminiCliSdk.Options{model: Models.default_model()}

# Use the fast model
opts = %GeminiCliSdk.Options{model: Models.fast_model()}

# List all built-in models
Models.available_models()
# => ["auto-gemini-3", "auto-gemini-2.5", ...]
```

## Aliases

`Models.resolve/1` validates Gemini CLI model values and expands local
convenience aliases:

```elixir
Models.resolve("pro")     # => "pro"
Models.resolve("flash")   # => "flash"
Models.resolve("default") # => "auto-gemini-3"
Models.resolve("fast")    # => "gemini-3.1-flash-lite-preview"

# Known concrete names pass through unchanged after validation
Models.resolve("gemini-3.1-pro-preview")
# => "gemini-3.1-pro-preview"
```

## Using Preview Models

The SDK validates raw model values through `cli_subprocess_core`. Add new
models to the shared core registry before using them here.

```elixir
# Use a preview model that is present in the shared core registry
opts = %GeminiCliSdk.Options{model: "gemini-3-flash-preview"}
{:ok, response} = GeminiCliSdk.run("Hello", opts)
```

## Validation

```elixir
Models.validate("gemini-3.1-flash-lite-preview") # => :ok
Models.validate("auto-gemini-3")                 # => :ok
Models.validate(nil)                             # => :ok (uses CLI default)
Models.validate("")                              # => {:error, "Invalid model: ..."}
Models.validate(123)                             # => {:error, "Invalid model: ..."}
```

## Checking Known Models

```elixir
Models.known?("gemini-3.1-flash-lite-preview") # => true
Models.known?("flash")                         # => true
Models.known?("custom-model")                  # => false
```

## Runtime Configuration

`Models.default_model/0` and `Models.fast_model/0` read from the shared core
registry. Application config is only a fallback if that registry is unavailable:

```elixir
# config/config.exs
config :gemini_cli_sdk,
  default_model: "auto-gemini-3",
  fast_model: "gemini-3.1-flash-lite-preview"
```

After this configuration:

```elixir
Models.default_model()  # => "auto-gemini-3"
Models.fast_model()     # => "gemini-3.1-flash-lite-preview"
```

## Per-Environment Configuration

```elixir
# config/dev.exs
config :gemini_cli_sdk,
  default_model: "auto-gemini-2.5"

# config/prod.exs
config :gemini_cli_sdk,
  default_model: "auto-gemini-3"
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
