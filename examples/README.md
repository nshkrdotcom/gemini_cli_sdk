# GeminiCliSdk Examples

These examples demonstrate real usage of GeminiCliSdk against the live Gemini CLI. They require:

1. Gemini CLI installed and authenticated (`gemini auth login`)
2. Dependencies fetched (`mix deps.get`)

## Running Examples

Run a single example:

```bash
mix run examples/simple_prompt.exs
```

Run all examples:

```bash
bash examples/run_all.sh
```

Run a specific example by name:

```bash
bash examples/run_all.sh streaming
```

## Examples

| File | Description |
|------|-------------|
| `simple_prompt.exs` | Basic synchronous prompt and response |
| `streaming.exs` | Real-time streaming with event handling |
| `sync_execution.exs` | Multiple synchronous prompts in sequence |
| `model_selection.exs` | Using different models |
| `error_handling.exs` | Graceful error handling patterns |
| `tool_use.exs` | Capturing tool use and result events |
| `session_management.exs` | Listing and managing sessions |
| `yolo_mode.exs` | Auto-approval mode for tool calls |

## Notes

- All examples use the **live** Gemini CLI -- they make real API calls
- Each example is self-contained and can be run independently
- Examples print diagnostic info to stderr and content to stdout
- Timeouts are set conservatively; adjust `timeout_ms` if needed
