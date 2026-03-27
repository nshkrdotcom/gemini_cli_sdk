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

  alias CliSubprocessCore.CommandSpec, as: CoreCommandSpec
  alias CliSubprocessCore.ProviderCLI
  alias CliSubprocessCore.ProviderCLI.Error, as: ProviderCLIError
  alias GeminiCliSdk.Error

  defmodule CommandSpec do
    @moduledoc "Describes a resolved CLI binary: the program path and any argv prefix."

    alias CliSubprocessCore.CommandSpec, as: CoreCommandSpec

    @enforce_keys [:program]
    defstruct program: "", argv_prefix: []

    @type t :: %__MODULE__{
            program: String.t(),
            argv_prefix: [String.t()]
          }

    @spec from_core(CoreCommandSpec.t()) :: t()
    def from_core(%CoreCommandSpec{} = spec) do
      %__MODULE__{
        program: spec.program,
        argv_prefix: spec.argv_prefix
      }
    end

    @spec to_core(t()) :: CoreCommandSpec.t()
    def to_core(%__MODULE__{} = spec) do
      CoreCommandSpec.new(spec.program, argv_prefix: spec.argv_prefix)
    end
  end

  @spec resolve() :: {:ok, CommandSpec.t()} | {:error, Error.t()}
  def resolve do
    case ProviderCLI.resolve(:gemini) do
      {:ok, %CoreCommandSpec{} = spec} ->
        {:ok, CommandSpec.from_core(spec)}

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
    spec
    |> CommandSpec.to_core()
    |> CoreCommandSpec.command_args(args)
  end

  @doc false
  @spec to_core_command_spec(CommandSpec.t()) :: CoreCommandSpec.t()
  def to_core_command_spec(%CommandSpec{} = spec) do
    CommandSpec.to_core(spec)
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
