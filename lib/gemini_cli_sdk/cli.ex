defmodule GeminiCliSdk.CLI do
  @moduledoc """
  Resolves the Gemini CLI binary location.

  Resolution order:

  1. `GEMINI_CLI_PATH` environment variable (explicit path)
  2. `gemini` on system `PATH` (e.g. globally installed via npm)
  3. npm global bin directory (`npm prefix -g`/bin/gemini)
  4. `npx` fallback — runs `npx --yes gemini` (auto-downloads on first use)

  Set `GEMINI_NO_NPX=1` to disable the npx fallback.
  """

  alias GeminiCliSdk.Error

  defmodule CommandSpec do
    @moduledoc "Describes a resolved CLI binary: the program path and any argv prefix."

    @enforce_keys [:program]
    defstruct program: "", argv_prefix: []

    @type t :: %__MODULE__{
            program: String.t(),
            argv_prefix: [String.t()]
          }
  end

  @spec resolve() :: {:ok, CommandSpec.t()} | {:error, Error.t()}
  def resolve do
    case System.get_env("GEMINI_CLI_PATH") do
      nil -> resolve_auto()
      path -> resolve_explicit(path)
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
  def command_args(%CommandSpec{argv_prefix: prefix}, args) do
    prefix ++ args
  end

  defp resolve_explicit(path) do
    cond do
      not File.exists?(path) ->
        {:error,
         Error.new(
           kind: :cli_not_found,
           message: "GEMINI_CLI_PATH points to non-existent file: #{path}"
         )}

      not executable?(path) ->
        {:error,
         Error.new(
           kind: :cli_not_found,
           message: "GEMINI_CLI_PATH points to non-executable file: #{path}"
         )}

      true ->
        {:ok, %CommandSpec{program: path}}
    end
  end

  defp resolve_auto do
    with :miss <- find_on_path(),
         :miss <- find_in_npm_global(),
         :miss <- find_via_npx() do
      {:error,
       Error.new(
         kind: :cli_not_found,
         message:
           "Gemini CLI not found. Install with: npm install -g @google/gemini-cli " <>
             "— or ensure npx is available for automatic resolution."
       )}
    end
  end

  # Strategy 1: System PATH
  defp find_on_path do
    case System.find_executable("gemini") do
      nil -> :miss
      path -> {:ok, %CommandSpec{program: path}}
    end
  end

  # Strategy 2: npm global bin directory
  defp find_in_npm_global do
    with {:ok, npm_path} <- find_npm(),
         {:ok, prefix} <- npm_global_prefix(npm_path) do
      gemini_bin = Path.join([prefix, "bin", "gemini"])

      if File.exists?(gemini_bin) and executable?(gemini_bin) do
        {:ok, %CommandSpec{program: gemini_bin}}
      else
        :miss
      end
    else
      _ -> :miss
    end
  end

  # Strategy 3: npx fallback (auto-downloads if needed)
  defp find_via_npx do
    if npx_disabled?() do
      :miss
    else
      case System.find_executable("npx") do
        nil ->
          :miss

        npx_path ->
          {:ok,
           %CommandSpec{
             program: npx_path,
             argv_prefix: ["--yes", "--package", "@google/gemini-cli", "gemini"]
           }}
      end
    end
  end

  defp find_npm do
    case System.find_executable("npm") do
      nil -> :miss
      path -> {:ok, path}
    end
  end

  defp npm_global_prefix(npm_path) do
    case System.cmd(npm_path, ["prefix", "-g"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      _ -> :miss
    end
  rescue
    _ -> :miss
  end

  defp npx_disabled? do
    System.get_env("GEMINI_NO_NPX") in ["1", "true"]
  end

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} -> Bitwise.band(mode, 0o111) != 0
      _ -> false
    end
  end
end
