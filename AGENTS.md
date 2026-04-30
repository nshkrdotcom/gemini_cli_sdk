# Repository Guidelines

## Project Structure
- `lib/` contains public `GeminiCliSdk` modules and internal runtime adapters.
- `test/` contains ExUnit coverage; `test/support/` is test-only and may contain lower-runtime fixtures.
- `guides/`, `examples/`, `README.md`, and `CHANGELOG.md` must stay aligned with runtime and dependency behavior.
- `doc/` is generated output and should not be edited.

## Execution Plane Stack
- This SDK sits above `cli_subprocess_core`; do not expose raw `ExecutionPlane.*` internals in public APIs or docs.
- Use `CliSubprocessCore` facades for execution surfaces, transport errors, transport info, process exits, sessions, commands, and provider model policy.
- Keep `cli_subprocess_core` dependency resolution publish-aware: local path deps for sibling development, Hex constraints for release builds.

## ASM Boundary
- Gemini-specific flags, settings profiles, extensions, allowed tools, MCP server names, approval mode, skip-trust, and provider CLI sandbox behavior belong in this SDK first.
- Behavior can move upward into ASM only after all-four proof across Claude, Codex, Gemini, and Amp.
- Before asserting a Gemini-native setting or CLI flag exists, add or update `guides/provider_behavior_manifest.md` with vendored source, fixture, or live-smoke evidence.
- SDK-direct promotion examples in `examples/promotion_path/` must not import or alias ASM; hybrid examples belong in ASM or application repos.

## Gates
- Run `mix format`.
- Run `mix compile --warnings-as-errors`.
- Run `mix test`.
- Run `mix credo --strict`.
- Run `mix dialyzer`.
- Run `mix docs --warnings-as-errors`.
