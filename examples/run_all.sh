#!/usr/bin/env bash
# Run all GeminiCliSdk examples
#
# Prerequisites:
#   - Gemini CLI installed and authenticated (gemini auth login)
#   - Mix dependencies fetched (mix deps.get)
#
# Usage:
#   bash examples/run_all.sh          # Run all examples
#   bash examples/run_all.sh simple   # Run just one example

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

EXAMPLES=(
  simple_prompt
  sync_execution
  streaming
  model_selection
  error_handling
  tool_use
  session_management
  yolo_mode
)

run_example() {
  local name="$1"
  local file="examples/${name}.exs"

  if [ ! -f "$file" ]; then
    echo "ERROR: Example not found: $file" >&2
    return 1
  fi

  echo ""
  echo "================================================================"
  echo "  Running: $name"
  echo "================================================================"
  echo ""

  mix run "$file"

  echo ""
  echo "--- $name completed ---"
  echo ""
}

if [ $# -gt 0 ]; then
  run_example "$1"
  exit 0
fi

echo "GeminiCliSdk Examples"
echo "===================="
echo ""
echo "Running ${#EXAMPLES[@]} examples..."

for example in "${EXAMPLES[@]}"; do
  run_example "$example"
done

echo ""
echo "All examples completed."
