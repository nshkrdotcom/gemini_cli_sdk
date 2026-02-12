#!/usr/bin/env bash
set -euo pipefail

# --- PID tracking ---
if [ -n "${GEMINI_TEST_PID_FILE:-}" ]; then
  echo $$ > "$GEMINI_TEST_PID_FILE"
fi

# --- Argument capture ---
if [ -n "${GEMINI_TEST_ARGS_FILE:-}" ]; then
  printf '%s\n' "$@" > "$GEMINI_TEST_ARGS_FILE"
fi

# --- Stdin capture ---
if [ -n "${GEMINI_TEST_STDIN_FILE:-}" ]; then
  cat > "$GEMINI_TEST_STDIN_FILE"
else
  cat > /dev/null || true
fi

# --- Blocking mode ---
if [ "${GEMINI_TEST_BLOCK:-0}" = "1" ]; then
  tail -f /dev/null
fi

# --- Delay before output ---
if [ -n "${GEMINI_TEST_DELAY_MS:-}" ]; then
  sleep "$(echo "scale=3; ${GEMINI_TEST_DELAY_MS}/1000" | bc)"
fi

# --- Stderr output ---
if [ -n "${GEMINI_TEST_STDERR:-}" ]; then
  echo "$GEMINI_TEST_STDERR" >&2
fi

# --- Exit code control ---
exit_code="${GEMINI_TEST_EXIT_CODE:-0}"

# --- Streaming output from file ---
if [ -n "${GEMINI_TEST_STREAM_FILE:-}" ]; then
  stream_delay="${GEMINI_TEST_STREAM_DELAY_MS:-0}"
  while IFS= read -r line || [ -n "$line" ]; do
    echo "$line"
    if [ "$stream_delay" != "0" ]; then
      sleep "$(echo "scale=3; ${stream_delay}/1000" | bc)"
    fi
  done < "$GEMINI_TEST_STREAM_FILE"
  exit "$exit_code"
fi

# --- Single-shot output from env var ---
if [ -n "${GEMINI_TEST_OUTPUT:-}" ]; then
  echo "$GEMINI_TEST_OUTPUT"
  exit "$exit_code"
fi

# --- Single-shot output from file ---
if [ -n "${GEMINI_TEST_OUTPUT_FILE:-}" ]; then
  cat "$GEMINI_TEST_OUTPUT_FILE"
  exit "$exit_code"
fi

# --- Default: no output, just exit ---
exit "$exit_code"
