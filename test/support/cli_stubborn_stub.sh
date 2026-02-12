#!/usr/bin/env bash
set -euo pipefail

if [ -n "${GEMINI_TEST_PID_FILE:-}" ]; then
  echo $$ > "$GEMINI_TEST_PID_FILE"
fi

# Ignore TERM and INT signals
trap '' TERM
trap '' INT

# Emit one line so the test knows we started, then block
echo '{"type":"init","session_id":"stubborn","model":"gemini-3.0-pro"}'
tail -f /dev/null
