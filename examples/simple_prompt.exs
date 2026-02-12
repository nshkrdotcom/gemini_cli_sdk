# Simple Prompt Example
#
# Sends a basic prompt to Gemini and prints the response.
#
# Usage:
#   mix run examples/simple_prompt.exs

IO.puts("=== Simple Prompt ===\n")

case GeminiCliSdk.run("What is Elixir in one sentence?") do
  {:ok, response} ->
    IO.puts(response)

  {:error, error} ->
    IO.puts(:stderr, "Error: #{Exception.message(error)}")
    System.halt(1)
end
