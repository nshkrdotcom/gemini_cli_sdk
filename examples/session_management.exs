# Session Management Example
#
# Demonstrates listing, inspecting, and managing Gemini sessions.
#
# Usage:
#   mix run examples/session_management.exs

IO.puts("=== Session Management ===\n")

# List available sessions
IO.puts("--- Listing Sessions ---")

case GeminiCliSdk.list_sessions() do
  {:ok, output} ->
    IO.puts(output)

  {:error, error} ->
    IO.puts(:stderr, "Could not list sessions: #{Exception.message(error)}")
end

IO.puts("")

# Show version info
IO.puts("--- CLI Version ---")

case GeminiCliSdk.version() do
  {:ok, version} ->
    IO.puts(version)

  {:error, error} ->
    IO.puts(:stderr, "Could not get version: #{Exception.message(error)}")
end
