defmodule GeminiCliSdk.Command do
  @moduledoc """
  Synchronous Gemini command helpers built on the shared core command lane.
  """

  alias CliSubprocessCore.Command, as: CoreCommand
  alias CliSubprocessCore.Command.Error, as: CoreCommandError
  alias CliSubprocessCore.CommandSpec
  alias CliSubprocessCore.ProcessExit
  alias CliSubprocessCore.Transport.Error, as: CoreTransportError
  alias CliSubprocessCore.Transport.RunResult
  alias GeminiCliSdk.{CLI, Configuration, Env, Error, Options}

  @type run_opt ::
          {:timeout, non_neg_integer() | :infinity}
          | {:stdin, iodata()}
          | {:cd, String.t()}
          | {:env, map() | keyword()}
          | {:execution_surface, CliSubprocessCore.ExecutionSurface.t() | map() | keyword()}

  @spec run([String.t()], [run_opt()]) :: {:ok, String.t()} | {:error, Error.t()}
  def run(args, opts \\ []) when is_list(args) and is_list(opts) do
    with {:ok, command} <- CLI.resolve() do
      run(command, args, opts)
    end
  end

  @spec run(CommandSpec.t(), [String.t()], [run_opt()]) ::
          {:ok, String.t()} | {:error, Error.t()}
  def run(%CommandSpec{} = command, args, opts) when is_list(args) and is_list(opts) do
    with {:ok, execution_surface_opts} <- execution_surface_options(opts) do
      timeout = Keyword.get(opts, :timeout, Configuration.command_timeout_ms())
      command_args = CLI.command_args(command, args)
      invocation = build_invocation(command, args, opts)

      case CoreCommand.run(
             invocation,
             [
               stdin: Keyword.get(opts, :stdin),
               timeout: timeout,
               stderr: :separate
             ] ++ execution_surface_opts
           ) do
        {:ok, %RunResult{} = result} ->
          handle_run_result(result)

        {:error, %CoreCommandError{} = error} ->
          {:error, translate_command_error(error, timeout, command.program, command_args)}
      end
    end
  end

  defp build_invocation(%CommandSpec{} = command, args, opts) do
    CoreCommand.new(
      command,
      args,
      cwd: Keyword.get(opts, :cd),
      env: Env.build_cli_env(normalize_env(Keyword.get(opts, :env)))
    )
  end

  defp handle_run_result(%RunResult{exit: %ProcessExit{status: :success}} = result) do
    {:ok, result |> combined_output() |> String.trim()}
  end

  defp handle_run_result(%RunResult{exit: %ProcessExit{} = exit} = result) do
    code = exit.code || 1
    stderr_text = result |> combined_output() |> String.trim()

    {:error,
     Error.new(
       kind: exit_code_to_kind(code),
       message: "CLI exited with code #{code}: #{stderr_text}",
       exit_code: code,
       details: stderr_text
     )}
  end

  defp translate_command_error(
         %CoreCommandError{reason: {:transport, %CoreTransportError{reason: :timeout}}},
         timeout,
         _program,
         _args
       ) do
    Error.new(
      kind: :command_timeout,
      message: "Command timed out after #{timeout}ms",
      exit_code: 124
    )
  end

  defp translate_command_error(%CoreCommandError{} = error, _timeout, program, args) do
    reason = unwrap_command_error_reason(error)

    Error.new(
      kind: :command_execution_failed,
      message: "Failed to execute command: #{format_reason(reason)}",
      cause: reason,
      context: Map.merge(error.context, %{program: program, args: args})
    )
  end

  defp combined_output(%RunResult{} = result), do: result.stdout <> result.stderr

  defp unwrap_command_error_reason(%CoreCommandError{
         reason: {:transport, %CoreTransportError{reason: reason}}
       }),
       do: reason

  defp unwrap_command_error_reason(%CoreCommandError{reason: reason}), do: reason

  defp format_reason(%_{} = exception) when is_exception(exception),
    do: Exception.message(exception)

  defp format_reason(reason), do: inspect(reason)

  defp exit_code_to_kind(41), do: :auth_error
  defp exit_code_to_kind(42), do: :input_error
  defp exit_code_to_kind(52), do: :config_error
  defp exit_code_to_kind(130), do: :user_cancelled
  defp exit_code_to_kind(_), do: :command_failed

  defp normalize_env(nil), do: %{}
  defp normalize_env(env) when is_map(env) or is_list(env), do: Env.normalize_overrides(env)

  defp execution_surface_options(opts) when is_list(opts) do
    case Options.normalize_execution_surface(Keyword.get(opts, :execution_surface)) do
      {:ok, execution_surface} ->
        {:ok, Options.execution_surface_options(execution_surface)}

      {:error, reason} ->
        {:error,
         Error.new(
           kind: :invalid_configuration,
           message: "invalid execution_surface: #{inspect(reason)}",
           cause: reason
         )}
    end
  end
end
