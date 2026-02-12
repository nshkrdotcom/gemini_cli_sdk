# Error Handling Example
#
# Demonstrates handling various error conditions gracefully.
#
# Usage:
#   mix run examples/error_handling.exs

alias GeminiCliSdk.Error

IO.puts("=== Error Handling ===\n")

# 1. Normal success case
IO.puts("--- Success Case ---")

case GeminiCliSdk.run("Say hello in one word") do
  {:ok, text} ->
    IO.puts("Success: #{text}")

  {:error, %Error{} = err} ->
    IO.puts(:stderr, "Unexpected error: #{Exception.message(err)}")
end

IO.puts("")

# 2. Timeout handling
IO.puts("--- Short Timeout ---")

short_opts = %GeminiCliSdk.Options{timeout_ms: 100}

case GeminiCliSdk.run("Write a 10000 word essay", short_opts) do
  {:ok, text} ->
    IO.puts("Got response (#{byte_size(text)} bytes)")

  {:error, %Error{} = err} ->
    IO.puts("Expected timeout/error: #{err.kind} - #{err.message}")
end

IO.puts("")

# 3. Pattern matching on error kinds
IO.puts("--- Error Kind Matching ---")

case GeminiCliSdk.run("Hello") do
  {:ok, text} ->
    IO.puts("Response: #{String.slice(text, 0, 100)}...")

  {:error, %Error{kind: :cli_not_found}} ->
    IO.puts(:stderr, "Gemini CLI not installed!")

  {:error, %Error{kind: :auth_error}} ->
    IO.puts(:stderr, "Not authenticated. Run: gemini auth login")

  {:error, %Error{kind: :command_timeout}} ->
    IO.puts(:stderr, "Timed out waiting for response")

  {:error, %Error{kind: kind, message: msg}} ->
    IO.puts(:stderr, "Error (#{kind}): #{msg}")
end
