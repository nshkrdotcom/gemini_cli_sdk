# Repository Guidelines

## Project Structure
- `lib/` contains public `GeminiCliSdk` modules and internal runtime adapters.
- `test/` contains ExUnit coverage; `test/support/` is test-only and may contain lower-runtime fixtures.
- `guides/`, `examples/`, `README.md`, and `CHANGELOG.md` must stay aligned with runtime and dependency behavior.
- `doc/` is generated output and should not be edited.

## Dependency Sources
- Gemini CLI SDK is not in the Weld consumer set. Do not add a Weld dependency, Weld task, or Weld Credo check as part of Phase 2 cleanup.
- Cross-repo dependency selection belongs in `build_support/dependency_sources.config.exs` and is consumed through the canonical `build_support/dependency_sources.exs` helper.
- Machine-local dependency overrides belong in `.dependency_sources.local.exs`. Keep that file untracked.
- Dependency source selection must not read environment variables.

## Execution Plane Stack
- This SDK sits above `cli_subprocess_core`; do not expose raw `ExecutionPlane.*` internals in public APIs or docs.
- Use `CliSubprocessCore` facades for execution surfaces, transport errors, transport info, process exits, sessions, commands, and provider model policy.
- Keep `cli_subprocess_core` dependency resolution publish-aware: local path deps for sibling development, Hex constraints for release builds.

## Runtime Environment
- Runtime application code under `lib/**` must not call direct OS environment APIs such as `System.get_env/1`, `System.fetch_env/1`, `System.fetch_env!/1`, `System.put_env/2`, `System.delete_env/1`, or `System.get_env/0`.
- Deployment environment reads belong at OTP boot boundaries such as `config/runtime.exs` or a `Config.Provider`. Runtime modules should receive explicit options or materialized application config.

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
