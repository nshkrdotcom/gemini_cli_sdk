# Gemini Provider Behavior Manifest

Provider-native Gemini CLI behavior must be proven here before the SDK translates
it. This manifest is SDK-owned evidence; it is not proof that ASM can expose the
feature as common behavior across providers.

| Feature | Evidence type | CLI version/source revision | Fixture | Live smoke | Known unsupported semantics | Date verified |
| --- | --- | --- | --- | --- | --- | --- |
| Gemini CLI argument rendering for model, approval mode, sandbox, skip trust, resume, extensions, include directories, allowed tools, and allowed MCP server names | vendored source and SDK render tests | vendored `gemini-cli` in this repo, current source tree | `test/gemini_cli_sdk/arg_builder_test.exs`; `test/gemini_cli_sdk/runtime/cli_test.exs` | `examples/promotion_path/sdk_direct_gemini.exs` | SDK-native only; ASM must not accept these as common provider options without all-four proof | 2026-04-29 |
| `SettingsProfiles.plain_response/0` Gemini settings map | vendored source and SDK settings tests | vendored `gemini-cli` in this repo, current source tree | `test/gemini_cli_sdk/settings_profiles_test.exs`; `test/gemini_cli_sdk/runtime/cli_test.exs` | `examples/promotion_path/sdk_direct_gemini.exs` | Gemini-native plain response/tool suppression only; not an ASM common `answer_only`, `tools: :none`, or `plain_response` contract | 2026-04-29 |
| Shared `execution_surface` normalization for local and SSH placement | source inspection note and SDK runtime tests | current `cli_subprocess_core` dependency | `test/gemini_cli_sdk/options_test.exs`; `test/gemini_cli_sdk/runtime/cli_test.exs` | `examples/promotion_path/sdk_direct_gemini.exs` for local keyword input; live SSH examples remain opt-in | Placement only; execution surface metadata must not become provider-native Gemini configuration | 2026-04-29 |
| Governed launch authority for command and session execution | SDK governed launch tests and shared core authority enforcement | current `cli_subprocess_core` dependency | `test/gemini_cli_sdk/governed_launch_test.exs` | Not a standalone live-smoke path; governed live proof is owned by later authority phases | Normal CLI discovery, native login state, settings-backed `.gemini` roots, cwd overrides, and execution-surface overrides are standalone direct-use behavior only | 2026-05-03 |
