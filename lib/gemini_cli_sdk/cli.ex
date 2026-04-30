defmodule GeminiCliSdk.CLI do
  @moduledoc """
  Resolves the Gemini CLI binary location through the shared
  `CliSubprocessCore.ProviderCLI` policy without SDK-owned environment
  variable controls.

  Resolution order:

  1. Explicit `:cli_command`, `:command`, `:executable`, or `:command_spec`
  2. `gemini` on system `PATH` (for example, globally installed via npm)
  3. npm global bin directory (`npm prefix -g`/bin/gemini)
  4. `npx` fallback, which runs
     `npx --yes --package @google/gemini-cli gemini`
  """

  alias CliSubprocessCore.CommandSpec
  alias CliSubprocessCore.ExecutionSurface
  alias CliSubprocessCore.ProviderCLI
  alias CliSubprocessCore.ProviderCLI.Error, as: ProviderCLIError
  alias GeminiCliSdk.Error

  import Bitwise, only: [&&&: 2]

  @resolve_option_keys [:execution_surface, :cli_command, :command, :executable, :command_spec]

  @spec resolve(CliSubprocessCore.ExecutionSurface.t() | map() | keyword() | nil) ::
          {:ok, CommandSpec.t()} | {:error, Error.t()}
  def resolve, do: do_resolve(nil, [])

  def resolve(opts) when is_list(opts) do
    if resolve_options?(opts) do
      execution_surface = Keyword.get(opts, :execution_surface)

      provider_opts =
        opts
        |> Keyword.take([:command, :executable, :command_spec])
        |> maybe_put_cli_command(Keyword.get(opts, :cli_command))

      do_resolve(execution_surface, provider_opts)
    else
      do_resolve(opts, [])
    end
  end

  def resolve(execution_surface) do
    do_resolve(execution_surface, [])
  end

  defp do_resolve(execution_surface, provider_opts) do
    with :ok <- validate_explicit_command(provider_opts, execution_surface) do
      case ProviderCLI.resolve(:gemini, provider_opts,
             execution_surface: execution_surface,
             env_var: nil,
             npx_disable_env: nil
           ) do
        {:ok, %CommandSpec{} = spec} ->
          {:ok, spec}

        {:error, %ProviderCLIError{} = error} ->
          {:error, translate_provider_cli_error(error)}
      end
    end
  end

  @spec resolve!(CliSubprocessCore.ExecutionSurface.t() | map() | keyword() | nil) ::
          CommandSpec.t()
  def resolve!(execution_surface \\ nil) do
    case resolve(execution_surface) do
      {:ok, spec} -> spec
      {:error, error} -> raise error
    end
  end

  @spec command_args(CommandSpec.t(), [String.t()]) :: [String.t()]
  def command_args(%CommandSpec{} = spec, args) do
    CommandSpec.command_args(spec, args)
  end

  defp resolve_options?(opts) do
    Enum.any?(@resolve_option_keys, &Keyword.has_key?(opts, &1))
  end

  defp maybe_put_cli_command(provider_opts, command) when is_binary(command) and command != "" do
    Keyword.put(provider_opts, :command, command)
  end

  defp maybe_put_cli_command(provider_opts, _command), do: provider_opts

  defp translate_provider_cli_error(%ProviderCLIError{} = error) do
    Error.new(
      kind: error.kind,
      message: error.message,
      cause: error.cause,
      context: %{provider: error.provider}
    )
  end

  defp validate_explicit_command(provider_opts, execution_surface) do
    command = Keyword.get(provider_opts, :command) || Keyword.get(provider_opts, :executable)

    cond do
      not is_binary(command) or command == "" ->
        :ok

      ExecutionSurface.nonlocal_path_surface?(execution_surface) ->
        :ok

      not path_like?(command) ->
        :ok

      not File.exists?(command) ->
        explicit_command_error(command, :missing)

      not executable_file?(command) ->
        explicit_command_error(command, :not_executable)

      true ->
        :ok
    end
  end

  defp path_like?(command), do: String.contains?(command, ["/", "\\"])

  defp executable_file?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular, mode: mode}} -> (mode &&& 0o111) != 0
      _ -> false
    end
  end

  defp explicit_command_error(command, reason) do
    {:error,
     Error.new(
       kind: :cli_not_found,
       message: explicit_command_message(command, reason),
       cause: reason,
       context: %{provider: :gemini}
     )}
  end

  defp explicit_command_message(command, reason) do
    message =
      case reason do
        :missing -> "does not exist"
        :not_executable -> "is not executable"
      end

    "Gemini CLI explicit command #{inspect(command)} #{message}"
  end
end
