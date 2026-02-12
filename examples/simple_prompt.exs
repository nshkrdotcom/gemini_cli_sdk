# Simple Prompt Example
#
# Sends a basic prompt to Gemini and prints the response.
#
# Usage:
#   mix run examples/simple_prompt.exs

IO.puts("=== Simple Prompt ===\n")

opts = %GeminiCliSdk.Options{model: GeminiCliSdk.Models.fast_model()}

case GeminiCliSdk.run("What is Elixir in one sentence?", opts) do
  {:ok, response} ->
    IO.puts(response)

  {:error, error} ->
    IO.puts(:stderr, "Error: #{Exception.message(error)}")
    System.halt(1)
end
