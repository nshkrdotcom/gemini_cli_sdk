defmodule GeminiCliSdk.CLITest do
  use ExUnit.Case, async: false

  alias CliSubprocessCore.CommandSpec
  alias GeminiCliSdk.CLI
  alias GeminiCliSdk.Error
  alias GeminiCliSdk.TestSupport

  describe "resolve/1 explicit command" do
    test "finds an explicit executable path" do
      dir = TestSupport.tmp_dir!("gemini_cli")
      gemini_path = TestSupport.write_cli_stub!(dir)

      try do
        assert {:ok, %CommandSpec{program: ^gemini_path}} =
                 CLI.resolve(cli_command: gemini_path)
      after
        File.rm_rf(dir)
      end
    end

    test "accepts an explicit command name" do
      assert {:ok, %CommandSpec{program: "gemini"}} = CLI.resolve(cli_command: "gemini")
    end

    test "returns an error for a missing explicit executable path" do
      missing_path = Path.join(TestSupport.tmp_dir!("gemini_missing_cli"), "missing-gemini")

      assert {:error, %Error{kind: :cli_not_found} = error} =
               CLI.resolve(cli_command: missing_path)

      assert error.message =~ "missing-gemini"
    end

    test "returns an error for a non-executable explicit path" do
      dir = TestSupport.tmp_dir!("gemini_cli_non_exec")
      non_exec = TestSupport.write_file!(dir, "gemini", "echo hi\n")

      try do
        assert {:error, %Error{kind: :cli_not_found}} = CLI.resolve(cli_command: non_exec)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "resolve/1 execution surfaces" do
    test "remote execution surfaces use the remote provider command by default" do
      assert {:ok, %CommandSpec{program: "gemini", argv_prefix: []}} =
               CLI.resolve(
                 surface_kind: :ssh_exec,
                 transport_options: [destination: "gemini.example"]
               )
    end

    test "explicit commands override the remote provider command when supplied" do
      assert {:ok, %CommandSpec{program: "/opt/gemini/bin/gemini", argv_prefix: []}} =
               CLI.resolve(
                 execution_surface: [
                   surface_kind: :ssh_exec,
                   transport_options: [destination: "gemini.example"]
                 ],
                 cli_command: "/opt/gemini/bin/gemini"
               )
    end
  end

  describe "resolve!/1" do
    test "returns core CommandSpec for an explicit executable" do
      dir = TestSupport.tmp_dir!("gemini_cli_resolve_bang")
      gemini_path = TestSupport.write_cli_stub!(dir)

      try do
        assert %CommandSpec{program: ^gemini_path} = CLI.resolve!(cli_command: gemini_path)
      after
        File.rm_rf(dir)
      end
    end

    test "raises when explicit executable cannot be found" do
      assert_raise Error, fn ->
        CLI.resolve!(cli_command: "/nonexistent/gemini")
      end
    end
  end
end
