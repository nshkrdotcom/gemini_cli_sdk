# Changelog

## Unreleased

- Runtime ownership and release docs now describe the final Phase 4 boundary:
  `cli_subprocess_core` owns Gemini subprocess lifecycle and `built-in transport`,
  `gemini_cli_sdk` owns Gemini-specific invocation and projection logic, and
  ASM composition remains common-surface-only with `namespaces: []`.

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
