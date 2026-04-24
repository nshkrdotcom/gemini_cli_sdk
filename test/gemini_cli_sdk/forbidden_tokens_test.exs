defmodule GeminiCliSdk.ForbiddenTokensTest do
  use ExUnit.Case, async: true

  @project_root Path.expand("../..", __DIR__)
  @legacy_backend Enum.join(["erl", "exec"])
  @forbidden_tokens [
    "ExternalRuntimeTransport",
    "external_runtime_transport"
  ]
  @stale_runtime_owner_tokens [
    "ExternalRuntimeTransport.Transport internals",
    Enum.join([
      "ExecutionPlane",
      ".Process (local) / ExternalRuntimeTransport.Transport (non-local)"
    ])
  ]
  @paths [
    "lib",
    "test",
    "mix.exs",
    "mix.lock",
    "README.md",
    "guides"
  ]
  @legacy_backend_paths [
    "lib",
    "test",
    "mix.exs",
    "README.md",
    "guides"
  ]

  test "shared CLI surfaces do not mention the legacy backend token" do
    Enum.each(expanded_files(@legacy_backend_paths), fn path ->
      if path != __ENV__.file do
        refute File.read!(path) =~ @legacy_backend,
               "unexpected legacy backend token in #{Path.relative_to(path, @project_root)}"
      end
    end)
  end

  test "public docs do not describe external_runtime_transport as the active runtime owner" do
    Enum.each(expanded_files(@paths), fn path ->
      if path != __ENV__.file do
        contents = File.read!(path)

        Enum.each(@stale_runtime_owner_tokens, fn token ->
          refute contents =~ token,
                 "unexpected stale runtime-owner token #{inspect(token)} in #{Path.relative_to(path, @project_root)}"
        end)
      end
    end)
  end

  test "repo contains no external runtime transport references" do
    Enum.each(expanded_files(@paths), fn path ->
      if path != __ENV__.file do
        contents = File.read!(path)

        Enum.each(@forbidden_tokens, fn token ->
          refute contents =~ token,
                 "unexpected forbidden token #{inspect(token)} in #{Path.relative_to(path, @project_root)}"
        end)
      end
    end)
  end

  defp expanded_files(paths) do
    paths
    |> Enum.flat_map(fn relative ->
      full_path = Path.join(@project_root, relative)

      cond do
        File.regular?(full_path) ->
          [full_path]

        File.dir?(full_path) ->
          Path.wildcard(Path.join(full_path, "**/*"))
          |> Enum.filter(&File.regular?/1)

        true ->
          []
      end
    end)
  end
end
