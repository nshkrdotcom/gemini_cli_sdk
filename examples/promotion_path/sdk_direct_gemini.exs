#!/usr/bin/env elixir

# SDK-direct Gemini promotion-path verifier.
#
# Usage:
#   mix run examples/promotion_path/sdk_direct_gemini.exs -- \
#     --model gemini-3.1-flash-lite-preview \
#     --prompt "Reply with exactly: gemini sdk direct ok"
#
# Optional:
#   --cli-command /path/to/gemini
#   --cwd /path/to/workdir

defmodule GeminiPromotionPath.Direct do
  @moduledoc false

  alias GeminiCliSdk.{Options, SettingsProfiles}

  @switches [
    cli_command: :string,
    cwd: :string,
    model: :string,
    prompt: :string
  ]

  def main(argv) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @switches)
    reject_invalid!(invalid)

    model = required!(opts, :model)
    prompt = Keyword.get(opts, :prompt) || Enum.join(args, " ")
    prompt = if String.trim(prompt) == "", do: "Reply with exactly: gemini sdk direct ok", else: prompt

    options = %Options{
      model: model,
      cli_command: Keyword.get(opts, :cli_command),
      cwd: Keyword.get(opts, :cwd),
      skip_trust: true,
      settings: SettingsProfiles.plain_response(),
      execution_surface: [
        surface_kind: :local_subprocess,
        observability: %{suite: :promotion_path, lane: :sdk_direct, provider: :gemini}
      ]
    }

    case GeminiCliSdk.run(prompt, options) do
      {:ok, response} ->
        IO.puts(response)

      {:error, error} ->
        IO.puts(:stderr, "Gemini SDK-direct example failed: #{Exception.message(error)}")
        System.halt(1)
    end
  end

  defp reject_invalid!([]), do: :ok

  defp reject_invalid!(invalid) do
    raise ArgumentError, "invalid options: #{inspect(invalid)}"
  end

  defp required!(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) ->
        if String.trim(value) == "" do
          missing_required!(key)
        else
          value
        end

      _ ->
        missing_required!(key)
    end
  end

  defp missing_required!(key) do
    IO.puts(:stderr, "Missing required --#{String.replace(to_string(key), "_", "-")}.")
    System.halt(64)
  end
end

GeminiPromotionPath.Direct.main(System.argv())
