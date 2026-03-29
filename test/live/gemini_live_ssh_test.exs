defmodule GeminiCliSdk.LiveSSHTest do
  use ExUnit.Case, async: false

  alias CliSubprocessCore.TestSupport.LiveSSH
  alias GeminiCliSdk.{Error, Options}

  @moduletag :live_ssh
  @moduletag timeout: 120_000

  @live_ssh_enabled LiveSSH.enabled?()

  if not @live_ssh_enabled do
    @moduletag skip: LiveSSH.skip_reason()
  end

  test "live SSH: GeminiCliSdk.run/2 returns a remote success or a structured runtime failure" do
    case GeminiCliSdk.run(
           "Say exactly: GEMINI_LIVE_SSH_OK",
           %Options{
             execution_surface: LiveSSH.execution_surface(),
             timeout_ms: 120_000
           }
         ) do
      {:ok, response} ->
        assert is_binary(response)
        assert response != ""

      {:error, %Error{kind: :cli_not_found} = error} ->
        assert error.message =~ "Gemini CLI not found"
        assert error.message =~ "remote"
        assert error.details =~ "No such file or directory"

      {:error, %Error{kind: :auth_error} = error} ->
        assert error.message =~ "authentication"
    end
  end
end
