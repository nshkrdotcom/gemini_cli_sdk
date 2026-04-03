defmodule GeminiCliSdk.ErrorTest do
  use ExUnit.Case, async: true

  alias CliSubprocessCore.ProviderCLI.ErrorRuntimeFailure
  alias GeminiCliSdk.Error

  test "new/1 creates error with kind and message" do
    error = Error.new(kind: :cli_not_found, message: "gemini not in PATH")
    assert %Error{kind: :cli_not_found, message: "gemini not in PATH"} = error
  end

  test "new/1 includes optional fields" do
    error =
      Error.new(
        kind: :command_failed,
        message: "exit 42",
        exit_code: 42,
        details: "auth error",
        cause: :enoent
      )

    assert error.exit_code == 42
    assert error.details == "auth error"
    assert error.cause == :enoent
  end

  test "Error implements Exception behaviour" do
    error = Error.new(kind: :cli_not_found, message: "gemini not found")
    assert Exception.message(error) =~ "gemini not found"
  end

  test "normalize/2 formats transport errors" do
    error = Error.normalize({:transport, :not_connected}, kind: :transport_error)
    assert error.kind == :transport_error
    assert error.message =~ "not connected"
  end

  test "from_runtime_failure/2 preserves provider-classified CLI failures" do
    failure =
      %ErrorRuntimeFailure{
        kind: :cli_not_found,
        provider: :gemini,
        message: "Gemini CLI not found on remote target ssh-target.example",
        exit_code: 127,
        stderr: "bash: line 1: gemini: command not found",
        context: %{remote?: true, destination: "ssh-target.example"}
      }

    error = Error.from_runtime_failure(failure)
    assert error.kind == :cli_not_found
    assert error.exit_code == 127
    assert error.details =~ "command not found"
    assert error.context.destination == "ssh-target.example"
  end

  test "normalize/2 formats timeout errors" do
    error = Error.normalize(:timeout, kind: :stream_timeout)
    assert error.kind == :stream_timeout
    assert error.message =~ "timed out"
  end

  test "normalize/2 preserves the wrapped error kind when adding a startup envelope" do
    original = Error.new(kind: :cli_not_found, message: "Gemini CLI not found")

    wrapped = Error.normalize(original, kind: :stream_start_failed)

    assert wrapped.kind == :stream_start_failed
    assert wrapped.context.underlying_kind == :cli_not_found
    assert %Error{kind: :cli_not_found} = wrapped.cause
  end

  describe "from_exit_code/1" do
    test "maps exit code 0 to success" do
      assert :ok = Error.from_exit_code(0)
    end

    test "maps exit code 41 to auth_error" do
      assert %Error{kind: :auth_error, exit_code: 41} = Error.from_exit_code(41)
    end

    test "maps exit code 42 to input_error" do
      assert %Error{kind: :input_error, exit_code: 42} = Error.from_exit_code(42)
    end

    test "maps exit code 52 to config_error" do
      assert %Error{kind: :config_error, exit_code: 52} = Error.from_exit_code(52)
    end

    test "maps exit code 130 to user_cancelled" do
      assert %Error{kind: :user_cancelled, exit_code: 130} = Error.from_exit_code(130)
    end

    test "maps unknown exit code to command_failed" do
      assert %Error{kind: :command_failed, exit_code: 7} = Error.from_exit_code(7)
    end
  end
end
