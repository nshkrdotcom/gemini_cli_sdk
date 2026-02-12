defmodule GeminiCliSdk.CLITest do
  use ExUnit.Case, async: false

  alias GeminiCliSdk.CLI
  alias GeminiCliSdk.CLI.CommandSpec
  alias GeminiCliSdk.Error
  alias GeminiCliSdk.TestSupport

  # Helper: env that disables all auto-resolution except what the test controls
  defp isolated_env(overrides \\ %{}) do
    Map.merge(
      %{
        "GEMINI_CLI_PATH" => nil,
        "PATH" => "/nonexistent_dir_only",
        "GEMINI_NO_NPX" => "1"
      },
      overrides
    )
  end

  describe "resolve/0 — GEMINI_CLI_PATH" do
    test "finds gemini via GEMINI_CLI_PATH env var" do
      dir = TestSupport.tmp_dir!("gemini_cli")
      gemini_path = TestSupport.write_executable!(dir, "gemini", "#!/bin/bash\nexit 0\n")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => gemini_path}, fn ->
          assert {:ok, %CommandSpec{program: ^gemini_path}} = CLI.resolve()
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "returns error for nonexistent GEMINI_CLI_PATH" do
      TestSupport.with_env(
        %{"GEMINI_CLI_PATH" => "/nonexistent/gemini"},
        fn ->
          assert {:error, %Error{kind: :cli_not_found}} = CLI.resolve()
        end
      )
    end

    test "returns error for non-executable GEMINI_CLI_PATH" do
      dir = TestSupport.tmp_dir!("gemini_cli_non_exec")
      non_exec = TestSupport.write_file!(dir, "gemini", "echo hi\n")

      try do
        TestSupport.with_env(
          %{"GEMINI_CLI_PATH" => non_exec},
          fn ->
            assert {:error, %Error{kind: :cli_not_found}} = CLI.resolve()
          end
        )
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "resolve/0 — PATH lookup" do
    test "finds gemini in PATH when GEMINI_CLI_PATH is not set" do
      dir = TestSupport.tmp_dir!("gemini_cli_path")
      TestSupport.write_executable!(dir, "gemini", "#!/bin/bash\nexit 0\n")
      path = dir <> ":" <> (System.get_env("PATH") || "")

      try do
        TestSupport.with_env(
          %{"GEMINI_CLI_PATH" => nil, "PATH" => path},
          fn ->
            assert {:ok, %CommandSpec{}} = CLI.resolve()
          end
        )
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "resolve/0 — npm global bin" do
    test "finds gemini in npm global prefix bin directory" do
      # Create a fake npm that reports our temp dir as its global prefix
      dir = TestSupport.tmp_dir!("gemini_npm_global")
      npm_dir = TestSupport.tmp_dir!("gemini_npm_bin")
      prefix_dir = TestSupport.tmp_dir!("gemini_prefix")

      # Create gemini binary in prefix/bin/
      bin_dir = Path.join(prefix_dir, "bin")
      File.mkdir_p!(bin_dir)
      TestSupport.write_executable!(bin_dir, "gemini", "#!/bin/bash\nexit 0\n")

      # Create a fake npm that reports the prefix
      TestSupport.write_executable!(
        npm_dir,
        "npm",
        "#!/bin/bash\necho '#{prefix_dir}'\n"
      )

      path = npm_dir <> ":/nonexistent_dir_only"

      try do
        TestSupport.with_env(
          isolated_env(%{"PATH" => path}),
          fn ->
            assert {:ok, %CommandSpec{program: program}} = CLI.resolve()
            assert program == Path.join(bin_dir, "gemini")
          end
        )
      after
        File.rm_rf(dir)
        File.rm_rf(npm_dir)
        File.rm_rf(prefix_dir)
      end
    end

    test "skips npm global when gemini not in prefix bin" do
      npm_dir = TestSupport.tmp_dir!("gemini_npm_nobin")
      prefix_dir = TestSupport.tmp_dir!("gemini_prefix_empty")

      TestSupport.write_executable!(
        npm_dir,
        "npm",
        "#!/bin/bash\necho '#{prefix_dir}'\n"
      )

      path = npm_dir <> ":/nonexistent_dir_only"

      try do
        TestSupport.with_env(
          isolated_env(%{"PATH" => path}),
          fn ->
            assert {:error, %Error{kind: :cli_not_found}} = CLI.resolve()
          end
        )
      after
        File.rm_rf(npm_dir)
        File.rm_rf(prefix_dir)
      end
    end
  end

  describe "resolve/0 — npx fallback" do
    test "falls back to npx when gemini is not on PATH or in npm global" do
      npx_dir = TestSupport.tmp_dir!("gemini_npx")
      npx_path = TestSupport.write_executable!(npx_dir, "npx", "#!/bin/bash\nexit 0\n")
      path = npx_dir <> ":/nonexistent_dir_only"

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => nil,
            "PATH" => path,
            "GEMINI_NO_NPX" => nil
          },
          fn ->
            assert {:ok,
                    %CommandSpec{
                      program: ^npx_path,
                      argv_prefix: ["--yes", "--package", "@google/gemini-cli", "gemini"]
                    }} = CLI.resolve()
          end
        )
      after
        File.rm_rf(npx_dir)
      end
    end

    test "npx fallback is disabled when GEMINI_NO_NPX=1" do
      npx_dir = TestSupport.tmp_dir!("gemini_npx_disabled")
      TestSupport.write_executable!(npx_dir, "npx", "#!/bin/bash\nexit 0\n")
      path = npx_dir <> ":/nonexistent_dir_only"

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => nil,
            "PATH" => path,
            "GEMINI_NO_NPX" => "1"
          },
          fn ->
            assert {:error, %Error{kind: :cli_not_found}} = CLI.resolve()
          end
        )
      after
        File.rm_rf(npx_dir)
      end
    end

    test "npx fallback is disabled when GEMINI_NO_NPX=true" do
      npx_dir = TestSupport.tmp_dir!("gemini_npx_disabled_true")
      TestSupport.write_executable!(npx_dir, "npx", "#!/bin/bash\nexit 0\n")
      path = npx_dir <> ":/nonexistent_dir_only"

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => nil,
            "PATH" => path,
            "GEMINI_NO_NPX" => "true"
          },
          fn ->
            assert {:error, %Error{kind: :cli_not_found}} = CLI.resolve()
          end
        )
      after
        File.rm_rf(npx_dir)
      end
    end
  end

  describe "resolve/0 — nothing found" do
    test "returns error when gemini is not anywhere" do
      TestSupport.with_env(
        isolated_env(),
        fn ->
          assert {:error, %Error{kind: :cli_not_found}} = CLI.resolve()
        end
      )
    end
  end

  describe "resolve!/0" do
    test "returns CommandSpec when found" do
      dir = TestSupport.tmp_dir!("gemini_cli_resolve_bang")
      gemini_path = TestSupport.write_executable!(dir, "gemini", "#!/bin/bash\nexit 0\n")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => gemini_path}, fn ->
          assert %CommandSpec{program: ^gemini_path} = CLI.resolve!()
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "raises when no CLI can be found" do
      TestSupport.with_env(
        isolated_env(%{"GEMINI_CLI_PATH" => "/nonexistent/gemini"}),
        fn ->
          assert_raise Error, fn -> CLI.resolve!() end
        end
      )
    end
  end

  describe "command_args/2" do
    test "prepends argv_prefix to args (npx-style)" do
      spec = %CommandSpec{
        program: "/usr/bin/npx",
        argv_prefix: ["--yes", "--package", "@google/gemini-cli", "gemini"]
      }

      assert ["--yes", "--package", "@google/gemini-cli", "gemini", "--version"] =
               CLI.command_args(spec, ["--version"])
    end

    test "returns args unchanged when no prefix" do
      spec = %CommandSpec{program: "/usr/bin/gemini", argv_prefix: []}
      assert ["--version"] = CLI.command_args(spec, ["--version"])
    end
  end
end
