# Model Selection Example
#
# Demonstrates using different models for different tasks.
#
# Usage:
#   mix run examples/model_selection.exs

IO.puts("=== Model Selection ===\n")

models = ["gemini-2.5-flash", "gemini-2.5-pro"]

for model <- models do
  IO.puts("--- #{model} ---")

  opts = %GeminiCliSdk.Options{
    model: model,
    timeout_ms: 60_000
  }

  case GeminiCliSdk.run("What model are you? Reply in one sentence.", opts) do
    {:ok, response} ->
      IO.puts(response)
      IO.puts("")

    {:error, error} ->
      IO.puts(:stderr, "Error with #{model}: #{Exception.message(error)}")
  end
end
