defmodule GeminiCliSdk.LiveSSHTest do
  use ExUnit.Case, async: false

  alias CliSubprocessCore.TestSupport.LiveSSH
  alias GeminiCliSdk.Options

  @moduletag :live_ssh
  @moduletag timeout: 120_000

  @live_ssh_enabled LiveSSH.enabled?()

  if not @live_ssh_enabled do
    @moduletag skip: LiveSSH.skip_reason()
  end

  setup_all do
    {:ok,
     skip: not LiveSSH.runnable?("gemini"),
     skip_reason:
       "Remote SSH target #{inspect(LiveSSH.destination())} does not have a runnable `gemini --version`."}
  end

  test "live SSH: GeminiCliSdk.run/2 executes against the remote Gemini CLI", %{
    skip: skip?,
    skip_reason: skip_reason
  } do
    if skip? do
      assert is_binary(skip_reason)
    else
      assert {:ok, response} =
               GeminiCliSdk.run(
                 "Say exactly: GEMINI_LIVE_SSH_OK",
                 %Options{
                   execution_surface: LiveSSH.execution_surface(),
                   timeout_ms: 120_000
                 }
               )

      assert is_binary(response)
      assert response != ""
    end
  end
end
