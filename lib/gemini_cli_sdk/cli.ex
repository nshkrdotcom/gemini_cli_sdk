defmodule GeminiCliSdk.CLI do
  @moduledoc """
  Resolves the Gemini CLI binary location through the shared
  `CliSubprocessCore.ProviderCLI` policy.

  Resolution order:

  1. `GEMINI_CLI_PATH` environment variable (explicit path)
  2. `gemini` on system `PATH` (e.g. globally installed via npm)
  3. npm global bin directory (`npm prefix -g`/bin/gemini)
  4. `npx` fallback — runs
     `npx --yes --package @google/gemini-cli gemini`

  Set `GEMINI_NO_NPX=1` to disable the npx fallback.
  """

  alias CliSubprocessCore.CommandSpec
  alias CliSubprocessCore.ProviderCLI
  alias CliSubprocessCore.ProviderCLI.Error, as: ProviderCLIError
  alias GeminiCliSdk.Error

  @spec resolve() :: {:ok, CommandSpec.t()} | {:error, Error.t()}
  def resolve do
    case ProviderCLI.resolve(:gemini) do
      {:ok, %CommandSpec{} = spec} ->
        {:ok, spec}

      {:error, %ProviderCLIError{} = error} ->
        {:error, translate_provider_cli_error(error)}
    end
  end

  @spec resolve!() :: CommandSpec.t()
  def resolve! do
    case resolve() do
      {:ok, spec} -> spec
      {:error, error} -> raise error
    end
  end

  @spec command_args(CommandSpec.t(), [String.t()]) :: [String.t()]
  def command_args(%CommandSpec{} = spec, args) do
    CommandSpec.command_args(spec, args)
  end

  defp translate_provider_cli_error(%ProviderCLIError{} = error) do
    Error.new(
      kind: error.kind,
      message: error.message,
      cause: error.cause,
      context: %{provider: error.provider}
    )
  end
end
