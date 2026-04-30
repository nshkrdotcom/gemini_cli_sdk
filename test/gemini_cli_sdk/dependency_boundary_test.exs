defmodule GeminiCliSdk.DependencyBoundaryTest do
  use ExUnit.Case, async: true

  @forbidden_deps [
    :agent_session_manager,
    :claude_agent_sdk,
    :codex_sdk,
    :amp_sdk,
    :inference
  ]

  test "gemini_cli_sdk does not declare ASM or sibling SDK deps" do
    assert_forbidden_deps_absent(Mix.Project.config()[:deps], @forbidden_deps)
  end

  defp assert_forbidden_deps_absent(deps, forbidden_deps) when is_list(deps) do
    declared = MapSet.new(Enum.map(deps, &dep_name/1))

    Enum.each(forbidden_deps, fn dep ->
      refute MapSet.member?(declared, dep),
             "gemini_cli_sdk must not declare dependency on #{inspect(dep)}"
    end)
  end

  defp dep_name({name, _requirement}), do: name
  defp dep_name({name, _requirement, _opts}), do: name
end
