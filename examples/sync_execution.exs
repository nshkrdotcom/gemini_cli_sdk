# Synchronous Execution Example
#
# Demonstrates the simple run/2 API that blocks and returns the result.
#
# Usage:
#   mix run examples/sync_execution.exs

IO.puts("=== Synchronous Execution ===\n")

timeout_ms = 120_000

prompts = [
  "What is pattern matching in Elixir? Answer in one sentence.",
  "What is a GenServer? Answer in one sentence.",
  "What is a Supervisor? Answer in one sentence."
]

for {prompt, idx} <- Enum.with_index(prompts, 1) do
  IO.puts("#{idx}. #{prompt}")

  opts = %GeminiCliSdk.Options{model: GeminiCliSdk.Models.fast_model(), timeout_ms: timeout_ms}

  case GeminiCliSdk.run(prompt, opts) do
    {:ok, response} ->
      IO.puts("   => #{String.trim(response)}\n")

    {:error, error} ->
      IO.puts(:stderr, "   Error: #{Exception.message(error)}\n")
  end
end
