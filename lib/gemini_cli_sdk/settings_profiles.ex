defmodule GeminiCliSdk.SettingsProfiles do
  @moduledoc """
  Settings profiles for known Gemini CLI runtime shapes.

  Profiles in this module are plain maps that match Gemini CLI `settings.json`
  keys. The SDK only provides profiles for behavior that has been checked
  against the vendored Gemini CLI source.
  """

  @plain_response %{
    "tools" => %{
      "core" => [],
      "discoveryCommand" => "",
      "callCommand" => ""
    },
    "experimental" => %{
      "enableAgents" => false
    },
    "agents" => %{
      "overrides" => %{
        "codebase_investigator" => %{"enabled" => false},
        "cli_help" => %{"enabled" => false},
        "generalist" => %{"enabled" => false}
      }
    },
    "skills" => %{
      "enabled" => false
    },
    "admin" => %{
      "extensions" => %{"enabled" => false},
      "mcp" => %{"enabled" => false},
      "skills" => %{"enabled" => false}
    },
    "hooksConfig" => %{
      "enabled" => false,
      "notifications" => false
    },
    "general" => %{
      "plan" => %{"enabled" => false}
    },
    "useWriteTodos" => false
  }

  @doc """
  Returns a Gemini CLI settings map for plain text responses.

  The profile disables built-in tools, custom tool discovery, extensions, MCP,
  built-in agents, skills, hooks, plan mode, and todo tracking through settings
  keys supported by the vendored Gemini CLI source.
  """
  @spec plain_response() :: map()
  def plain_response, do: @plain_response
end
