defmodule GeminiCliSdk.CLI do
  @moduledoc "Resolves the Gemini CLI binary location."

  alias GeminiCliSdk.Error

  defmodule CommandSpec do
    @moduledoc false

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
      nil -> resolve_from_path()
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

  defp resolve_from_path do
    case System.find_executable("gemini") do
      nil ->
        {:error,
         Error.new(
           kind: :cli_not_found,
           message:
             "Gemini CLI not found. Install it with: npm install -g @anthropic-ai/gemini-cli"
         )}

      path ->
        {:ok, %CommandSpec{program: path}}
    end
  end

  defp executable?(path) do
    case System.cmd("test", ["-x", path], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end
end
