defmodule GeminiCliSdk.SettingsProfilesTest do
  use ExUnit.Case, async: true

  alias GeminiCliSdk.SettingsProfiles

  describe "plain_response/0" do
    test "returns the proven Gemini CLI no-tool settings shape" do
      profile = SettingsProfiles.plain_response()

      assert profile["tools"]["core"] == []
      assert profile["tools"]["discoveryCommand"] == ""
      assert profile["tools"]["callCommand"] == ""
      assert profile["experimental"]["enableAgents"] == false

      assert profile["agents"]["overrides"]["codebase_investigator"]["enabled"] == false
      assert profile["agents"]["overrides"]["cli_help"]["enabled"] == false
      assert profile["agents"]["overrides"]["generalist"]["enabled"] == false

      assert profile["skills"]["enabled"] == false
      assert profile["admin"]["extensions"]["enabled"] == false
      assert profile["admin"]["mcp"]["enabled"] == false
      assert profile["admin"]["skills"]["enabled"] == false
      assert profile["hooksConfig"]["enabled"] == false
      assert profile["hooksConfig"]["notifications"] == false
      assert profile["general"]["plan"]["enabled"] == false
      assert profile["useWriteTodos"] == false
    end
  end
end
