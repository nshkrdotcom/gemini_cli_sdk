# Changelog

## Unreleased

## v0.2.0 (2026-04-06)

### Added

- Session recovery helpers and a shared runtime support layer for examples,
  making resume/list flows consistent with the core-backed session lane.

### Changed

- Gemini streaming, one-shot execution, and session orchestration now run on
  `cli_subprocess_core`, while `gemini_cli_sdk` keeps Gemini-specific command
  shaping and event projection.
- Model normalization, execution-surface handling, and SSH routing now follow
  the shared core contract instead of provider-local fallback logic.
- Runtime ownership and release docs now describe the final Phase 4 boundary:
  `cli_subprocess_core` owns Gemini subprocess lifecycle and built-in transport,
  `gemini_cli_sdk` owns Gemini-specific invocation and projection logic, and
  ASM composition remains common-surface-only with `namespaces: []`.

### Fixed

- Error wrapping and context preservation are more consistent across stream and
  synchronous paths, especially for remote/SSH-backed execution failures.
- Guest-path and nonlocal CWD handling now align with the shared execution
  surface contract.

## v0.1.0 (2026-02-11)

Initial release.

- Streaming execution via `GeminiCliSdk.execute/2` with lazy `Stream.resource/3`
- Synchronous execution via `GeminiCliSdk.run/2`
- Session management: list, resume, delete
- 6 typed event structs: init, message, tool_use, tool_result, error, result
- Full CLI options support: model, yolo, approval_mode, sandbox, extensions, etc.
- Subprocess management via built-in transport with process groups and signal delivery
- Structured error handling with exit code mapping
- OTP application with TaskSupervisor

[Unreleased]: https://github.com/nshkrdotcom/gemini_cli_sdk/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/nshkrdotcom/gemini_cli_sdk/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/nshkrdotcom/gemini_cli_sdk/releases/tag/v0.1.0
