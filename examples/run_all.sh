#!/usr/bin/env bash
# Run all GeminiCliSdk examples
#
# Prerequisites:
#   - Gemini CLI installed and authenticated (gemini auth login)
#   - Mix dependencies fetched (mix deps.get)
#
# Usage:
#   bash examples/run_all.sh
#   bash examples/run_all.sh streaming
#   bash examples/run_all.sh --ssh-host example.internal
#   bash examples/run_all.sh --ssh-host example.internal --danger-full-access
#   bash examples/run_all.sh streaming --ssh-host builder@example.internal --ssh-port 2222

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
  shift

  if [ ! -f "$file" ]; then
    echo "ERROR: Example not found: $file" >&2
    return 1
  fi

  echo ""
  echo "================================================================"
  echo "  Running: $name"
  echo "================================================================"
  echo ""

  if [ "$#" -gt 0 ]; then
    mix run "$file" -- "$@"
  else
    mix run "$file"
  fi

  echo ""
  echo "--- $name completed ---"
  echo ""
}

usage() {
  cat <<'EOF'
Usage:
  bash examples/run_all.sh [example_name] [--cwd PATH] [--danger-full-access] [--ssh-host HOST] [--ssh-user USER] [--ssh-port PORT] [--ssh-identity-file PATH]

Examples:
  bash examples/run_all.sh
  bash examples/run_all.sh streaming
  bash examples/run_all.sh --ssh-host example.internal
  bash examples/run_all.sh --ssh-host example.internal --danger-full-access
  bash examples/run_all.sh session_management --ssh-host builder@example.internal --ssh-port 2222
EOF
}

selected_example=""
forward_args=()
ssh_host=""
ssh_aux_set=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --cwd|--ssh-host|--ssh-user|--ssh-port|--ssh-identity-file)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: $1 requires a value." >&2
        exit 1
      fi

      if [[ "$1" == "--ssh-host" ]]; then
        ssh_host="$2"
      elif [[ "$1" == --ssh-* ]]; then
        ssh_aux_set=1
      fi

      forward_args+=("$1" "$2")
      shift 2
      ;;
    --cwd=*|--ssh-host=*|--ssh-user=*|--ssh-port=*|--ssh-identity-file=*)
      if [[ "$1" == --ssh-host=* ]]; then
        ssh_host="${1#*=}"
      elif [[ "$1" == --ssh-* ]]; then
        ssh_aux_set=1
      fi

      forward_args+=("$1")
      shift
      ;;
    --danger-full-access)
      forward_args+=("$1")
      shift
      ;;
    -*)
      echo "ERROR: unknown argument: $1" >&2
      echo "" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$selected_example" ]]; then
        echo "ERROR: only one example name may be provided." >&2
        exit 1
      fi

      selected_example="$1"
      shift
      ;;
  esac
done

if [[ -z "$ssh_host" && "$ssh_aux_set" -eq 1 ]]; then
  echo "ERROR: --ssh-user/--ssh-port/--ssh-identity-file require --ssh-host." >&2
  exit 1
fi

if [[ -n "$selected_example" ]]; then
  run_example "$selected_example" "${forward_args[@]}"
  exit 0
fi

echo "GeminiCliSdk Examples"
echo "===================="
echo ""
echo "Running ${#EXAMPLES[@]} examples..."

for example in "${EXAMPLES[@]}"; do
  run_example "$example" "${forward_args[@]}"
done

echo ""
echo "All examples completed."
