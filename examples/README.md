# GeminiCliSdk Examples

These examples demonstrate real usage of GeminiCliSdk against the live Gemini CLI. They require:

1. Gemini CLI installed and authenticated (`gemini auth login`)
2. Dependencies fetched (`mix deps.get`)

## Running Examples

Run a single example:

```bash
mix run examples/simple_prompt.exs
mix run examples/simple_prompt.exs -- --ssh-host example.internal
mix run examples/simple_prompt.exs -- --ssh-host example.internal --danger-full-access
```

Run all examples:

```bash
bash examples/run_all.sh
bash examples/run_all.sh --ssh-host example.internal
bash examples/run_all.sh --ssh-host example.internal --danger-full-access
```

Run a specific example by name:

```bash
bash examples/run_all.sh streaming
bash examples/run_all.sh session_management --ssh-host builder@example.internal --ssh-port 2222
```

## Shared SSH Flags

Every example in this directory accepts the same optional SSH transport flags:

- `--cwd <path>` passes an explicit working directory to the example
- `--danger-full-access` maps the example to the Gemini permissive runtime posture
- `--ssh-host <host>` switches the example to `execution_surface: :ssh_exec`
- `--ssh-user <user>` overrides the SSH user
- `--ssh-port <port>` overrides the SSH port
- `--ssh-identity-file <path>` sets the SSH identity file

If you omit the SSH flags, the examples keep the existing local subprocess
default unchanged.

For Gemini, `--danger-full-access` keeps the same transport placement and
switches the example to the permissive runtime combination
`approval_mode: :yolo` with sandboxing disabled.

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
- Pass example flags after `--` when using `mix run`, for example:
  `mix run examples/streaming.exs -- --ssh-host example.internal --danger-full-access`
## Recovery-Oriented Examples

The existing example lane already covers the new session surfaces:

- `examples/session_management.exs`

That example is the right place to look for listing and resuming Gemini sessions, and the
top-level `examples/run_all.sh` runner already includes it in the default sequence.
