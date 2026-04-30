defmodule GeminiCliSdk.Command do
  @moduledoc """
  Synchronous Gemini command helpers built on the shared core command lane.
  """

  alias CliSubprocessCore.Command, as: CoreCommand
  alias CliSubprocessCore.Command.Error, as: CoreCommandError
  alias CliSubprocessCore.Command.RunResult
  alias CliSubprocessCore.CommandSpec
  alias CliSubprocessCore.ProcessExit
  alias CliSubprocessCore.ProviderCLI
  alias CliSubprocessCore.TransportError, as: CoreTransportError
  alias GeminiCliSdk.{CLI, Configuration, Error, Options}

  @type run_opt ::
          {:timeout, non_neg_integer() | :infinity}
          | {:stdin, iodata()}
          | {:cd, String.t()}
          | {:cli_command, String.t()}
          | {:execution_surface, CliSubprocessCore.ExecutionSurface.t() | map() | keyword()}

  @spec run([String.t()], [run_opt()]) :: {:ok, String.t()} | {:error, Error.t()}
  def run(args, opts \\ []) when is_list(args) and is_list(opts) do
    with :ok <- reject_unsupported_options(opts),
         {:ok, command} <- CLI.resolve(Keyword.take(opts, [:execution_surface, :cli_command])) do
      run(command, args, opts)
    end
  end

  @spec run(CommandSpec.t(), [String.t()], [run_opt()]) ::
          {:ok, String.t()} | {:error, Error.t()}
  def run(%CommandSpec{} = command, args, opts) when is_list(args) and is_list(opts) do
    with :ok <- reject_unsupported_options(opts),
         {:ok, execution_surface_opts} <- execution_surface_options(opts) do
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
          handle_run_result(result, command, command_args, opts)

        {:error, %CoreCommandError{} = error} ->
          {:error, translate_command_error(error, timeout, command, command_args, opts)}
      end
    end
  end

  defp build_invocation(%CommandSpec{} = command, args, opts) do
    CoreCommand.new(
      command,
      args,
      cwd: Keyword.get(opts, :cd)
    )
  end

  defp handle_run_result(
         %RunResult{exit: exit} = result,
         command,
         command_args,
         opts
       ) do
    if ProcessExit.successful?(exit) do
      {:ok, result |> combined_output() |> String.trim()}
    else
      handle_failed_run_result(result, command, command_args, opts)
    end
  end

  defp handle_failed_run_result(%RunResult{exit: exit} = result, command, command_args, opts) do
    failure =
      ProviderCLI.runtime_failure(
        :gemini,
        exit,
        execution_surface: Keyword.get(opts, :execution_surface),
        cwd: Keyword.get(opts, :cd),
        stderr: combined_output(result),
        command: command.program
      )

    error =
      case {failure.kind, Error.from_exit_code(ProcessExit.code(exit) || 1)} do
        {:process_exit, %Error{} = classified}
        when classified.kind in [:auth_error, :input_error, :config_error, :user_cancelled] ->
          %Error{
            classified
            | message: failure.message,
              details: combined_output(result),
              context: %{program: command.program, args: command_args}
          }

        {:process_exit, _other} ->
          Error.new(
            kind: :command_failed,
            message: failure.message,
            details: combined_output(result),
            context: %{program: command.program, args: command_args},
            exit_code: ProcessExit.code(exit)
          )

        _other ->
          Error.from_runtime_failure(failure,
            context: %{program: command.program, args: command_args}
          )
      end

    {:error, error}
  end

  defp translate_command_error(
         %CoreCommandError{reason: {:transport, error}} = command_error,
         timeout,
         command,
         args,
         opts
       ) do
    if CoreTransportError.reason(error) == :timeout do
      Error.new(
        kind: :command_timeout,
        message: "Command timed out after #{timeout}ms",
        exit_code: 124,
        context: %{program: command.program, args: args}
      )
    else
      translate_non_timeout_command_error(command_error, command, args, opts)
    end
  end

  defp translate_command_error(%CoreCommandError{} = error, _timeout, command, args, opts) do
    translate_non_timeout_command_error(error, command, args, opts)
  end

  defp translate_non_timeout_command_error(%CoreCommandError{} = error, command, args, opts) do
    reason = unwrap_command_error_reason(error)

    if provider_runtime_reason?(reason) do
      failure =
        ProviderCLI.runtime_failure(
          :gemini,
          reason,
          execution_surface: Keyword.get(opts, :execution_surface),
          cwd: Keyword.get(opts, :cd),
          command: command.program
        )

      Error.from_runtime_failure(failure,
        context: Map.merge(error.context, %{program: command.program, args: args})
      )
    else
      Error.new(
        kind: :command_execution_failed,
        message: "Failed to execute command: #{inspect(reason)}",
        cause: reason,
        context: Map.merge(error.context, %{program: command.program, args: args})
      )
    end
  end

  defp combined_output(%RunResult{} = result), do: result.stdout <> result.stderr

  defp unwrap_command_error_reason(%CoreCommandError{reason: {:transport, error}}) do
    if CoreTransportError.match?(error), do: CoreTransportError.reason(error), else: error
  end

  defp unwrap_command_error_reason(%CoreCommandError{reason: reason}), do: reason

  defp provider_runtime_reason?({:transport, reason}), do: CoreTransportError.match?(reason)

  defp provider_runtime_reason?(reason),
    do: CoreTransportError.match?(reason) or ProcessExit.match?(reason)

  defp reject_unsupported_options(opts) do
    unsupported_key = String.to_atom("env")

    if Keyword.has_key?(opts, unsupported_key) do
      {:error,
       Error.new(
         kind: :invalid_configuration,
         message: "unsupported command option: #{unsupported_key}"
       )}
    else
      :ok
    end
  end

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
