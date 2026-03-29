defmodule GeminiCliSdk.CommandTest do
  use ExUnit.Case, async: false

  alias CliSubprocessCore.TestSupport.FakeSSH
  alias GeminiCliSdk.Command
  alias GeminiCliSdk.Error
  alias GeminiCliSdk.TestSupport

  defp write_command_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -n "${GEMINI_TEST_PID_FILE:-}" ]; then
      echo $$ > "$GEMINI_TEST_PID_FILE"
    fi

    if [ -n "${GEMINI_TEST_ARGS_FILE:-}" ]; then
      printf '%s\\n' "$@" > "$GEMINI_TEST_ARGS_FILE"
    fi

    if [ -n "${GEMINI_TEST_STDIN_FILE:-}" ]; then
      cat > "$GEMINI_TEST_STDIN_FILE"
    else
      cat > /dev/null || true
    fi

    if [ "${GEMINI_TEST_BLOCK:-0}" = "1" ]; then
      tail -f /dev/null
    fi

    exit_code="${GEMINI_TEST_EXIT_CODE:-0}"
    if [ "$exit_code" != "0" ]; then
      echo "${GEMINI_TEST_STDERR:-command failed}" >&2
      exit "$exit_code"
    fi

    echo "${GEMINI_TEST_OUTPUT:-ok}"
    """

    TestSupport.write_executable!(dir, "gemini", script)
  end

  describe "run/2" do
    test "executes command and returns output" do
      dir = TestSupport.tmp_dir!("gemini_command")
      args_file = Path.join(dir, "args.txt")
      stub_path = write_command_stub!(dir)

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_ARGS_FILE" => args_file,
            "GEMINI_TEST_OUTPUT" => "session list output"
          },
          fn ->
            assert {:ok, output} = Command.run(["--list-sessions"])
            assert output =~ "session list output"
            assert File.read!(args_file) =~ "--list-sessions"
          end
        )
      after
        File.rm_rf(dir)
      end
    end

    test "maps non-zero exit to Error with exit_code" do
      dir = TestSupport.tmp_dir!("gemini_command_error")
      stub_path = write_command_stub!(dir)

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_EXIT_CODE" => "41",
            "GEMINI_TEST_STDERR" => "auth failed"
          },
          fn ->
            assert {:error, %Error{} = error} = Command.run(["--list-sessions"])
            assert error.exit_code == 41
            assert error.kind == :auth_error
          end
        )
      after
        File.rm_rf(dir)
      end
    end

    test "maps exit code 52 to config_error" do
      dir = TestSupport.tmp_dir!("gemini_command_config")
      stub_path = write_command_stub!(dir)

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_EXIT_CODE" => "52",
            "GEMINI_TEST_STDERR" => "invalid config"
          },
          fn ->
            assert {:error, %Error{kind: :config_error}} = Command.run(["--list-sessions"])
          end
        )
      after
        File.rm_rf(dir)
      end
    end

    test "enforces timeout" do
      dir = TestSupport.tmp_dir!("gemini_command_timeout")
      stub_path = write_command_stub!(dir)

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_BLOCK" => "1"
          },
          fn ->
            assert {:error, %Error{kind: :command_timeout}} =
                     Command.run(["--list-sessions"], timeout: 100)
          end
        )
      after
        File.rm_rf(dir)
      end
    end

    test "timeout stops the spawned subprocess" do
      dir = TestSupport.tmp_dir!("gemini_command_timeout_cleanup")
      pid_file = Path.join(dir, "pid.txt")
      stub_path = write_command_stub!(dir)

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_BLOCK" => "1",
            "GEMINI_TEST_PID_FILE" => pid_file
          },
          fn ->
            assert {:error, %Error{kind: :command_timeout}} =
                     Command.run(["--list-sessions"], timeout: 100)

            assert TestSupport.wait_until(fn -> File.exists?(pid_file) end, 1_000) == :ok

            pid =
              pid_file
              |> File.read!()
              |> String.trim()
              |> String.to_integer()

            assert TestSupport.wait_until(
                     fn -> not TestSupport.os_process_alive?(pid) end,
                     5_000
                   ) == :ok
          end
        )
      after
        File.rm_rf(dir)
      end
    end

    test "returns error when CLI not found" do
      TestSupport.with_env(
        %{"GEMINI_CLI_PATH" => "/nonexistent/gemini", "PATH" => "/nonexistent_dir_only"},
        fn ->
          assert {:error, %Error{kind: :cli_not_found}} =
                   Command.run(["--version"])
        end
      )
    end

    test "preserves execution_surface over the canonical fake SSH harness" do
      dir = TestSupport.tmp_dir!("gemini_command_fake_ssh")
      stub_path = write_command_stub!(dir)
      fake_ssh = FakeSSH.new!()

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_OUTPUT" => "session list output"
          },
          fn ->
            assert {:ok, output} =
                     Command.run(["--list-sessions"],
                       env: %{"PATH" => dir <> ":" <> (System.get_env("PATH") || "")},
                       execution_surface: [
                         surface_kind: :static_ssh,
                         transport_options:
                           FakeSSH.transport_options(fake_ssh,
                             destination: "gemini-command.test.example",
                             port: 2222
                           )
                       ]
                     )

            assert output =~ "session list output"
            assert FakeSSH.wait_until_written(fake_ssh, 1_000) == :ok

            assert FakeSSH.read_manifest!(fake_ssh) =~
                     "destination=gemini-command.test.example"
          end
        )
      after
        FakeSSH.cleanup(fake_ssh)
        File.rm_rf(dir)
      end
    end

    test "classifies missing remote Gemini CLI over SSH as :cli_not_found" do
      fake_ssh = FakeSSH.new!()

      try do
        TestSupport.with_env(%{"PATH" => "/nonexistent_dir_only", "GEMINI_CLI_PATH" => nil}, fn ->
          assert {:error, %Error{} = error} =
                   Command.run(["--version"],
                     execution_surface: [
                       surface_kind: :static_ssh,
                       transport_options:
                         FakeSSH.transport_options(fake_ssh,
                           destination: "gemini-command.missing.example"
                         )
                     ],
                     env: %{"PATH" => "/nonexistent_dir_only"}
                   )

          assert error.kind == :cli_not_found
          assert error.exit_code == 127
          assert error.message =~ "remote target gemini-command.missing.example"
        end)
      after
        FakeSSH.cleanup(fake_ssh)
      end
    end
  end
end
