defmodule GeminiCliSdk.CLITest do
  use ExUnit.Case, async: false

  alias GeminiCliSdk.CLI
  alias GeminiCliSdk.CLI.CommandSpec
  alias GeminiCliSdk.Error
  alias GeminiCliSdk.TestSupport

  describe "resolve/0" do
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

    test "returns error when gemini is not anywhere" do
      TestSupport.with_env(
        %{"GEMINI_CLI_PATH" => nil, "PATH" => "/nonexistent_dir_only"},
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
        %{"GEMINI_CLI_PATH" => "/nonexistent/gemini", "PATH" => "/nonexistent_dir_only"},
        fn ->
          assert_raise Error, fn -> CLI.resolve!() end
        end
      )
    end
  end

  describe "command_args/2" do
    test "prepends argv_prefix to args" do
      spec = %CommandSpec{program: "/usr/bin/node", argv_prefix: ["/path/to/gemini.js"]}
      assert ["/path/to/gemini.js", "--version"] = CLI.command_args(spec, ["--version"])
    end

    test "returns args unchanged when no prefix" do
      spec = %CommandSpec{program: "/usr/bin/gemini", argv_prefix: []}
      assert ["--version"] = CLI.command_args(spec, ["--version"])
    end
  end
end
