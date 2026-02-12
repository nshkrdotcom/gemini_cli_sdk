# Changelog

## v0.1.0 (2026-02-11)

Initial release.

- Streaming execution via `GeminiCliSdk.execute/2` with lazy `Stream.resource/3`
- Synchronous execution via `GeminiCliSdk.run/2`
- Session management: list, resume, delete
- 6 typed event structs: init, message, tool_use, tool_result, error, result
- Full CLI options support: model, yolo, approval_mode, sandbox, extensions, etc.
- Subprocess management via erlexec with process groups and signal delivery
- Structured error handling with exit code mapping
- OTP application with TaskSupervisor
