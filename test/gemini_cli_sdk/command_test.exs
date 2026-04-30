defmodule GeminiCliSdk.CommandTest do
  use ExUnit.Case, async: false

  alias CliSubprocessCore.TestSupport.FakeSSH
  alias GeminiCliSdk.Command
  alias GeminiCliSdk.Error
  alias GeminiCliSdk.TestSupport

  describe "run/2" do
    test "executes command and returns output" do
      dir = TestSupport.tmp_dir!("gemini_command")
      args_file = Path.join(dir, "args.txt")

      stub_path =
        TestSupport.write_cli_stub!(dir,
          args_file: args_file,
          output: "session list output"
        )

      try do
        assert {:ok, output} = Command.run(["--list-sessions"], cli_command: stub_path)
        assert output =~ "session list output"
        assert File.read!(args_file) =~ "--list-sessions"
      after
        File.rm_rf(dir)
      end
    end

    test "maps non-zero exit to Error with exit_code" do
      dir = TestSupport.tmp_dir!("gemini_command_error")
      stub_path = TestSupport.write_cli_stub!(dir, exit_code: 41, stderr: "auth failed")

      try do
        assert {:error, %Error{} = error} =
                 Command.run(["--list-sessions"], cli_command: stub_path)

        assert error.exit_code == 41
        assert error.kind == :auth_error
      after
        File.rm_rf(dir)
      end
    end

    test "maps exit code 52 to config_error" do
      dir = TestSupport.tmp_dir!("gemini_command_config")
      stub_path = TestSupport.write_cli_stub!(dir, exit_code: 52, stderr: "invalid config")

      try do
        assert {:error, %Error{kind: :config_error}} =
                 Command.run(["--list-sessions"], cli_command: stub_path)
      after
        File.rm_rf(dir)
      end
    end

    test "enforces timeout" do
      dir = TestSupport.tmp_dir!("gemini_command_timeout")
      stub_path = TestSupport.write_cli_stub!(dir, block?: true)

      try do
        assert {:error, %Error{kind: :command_timeout}} =
                 Command.run(["--list-sessions"], cli_command: stub_path, timeout: 100)
      after
        File.rm_rf(dir)
      end
    end

    test "timeout stops the spawned subprocess" do
      dir = TestSupport.tmp_dir!("gemini_command_timeout_cleanup")
      pid_file = Path.join(dir, "pid.txt")
      stub_path = TestSupport.write_cli_stub!(dir, block?: true, pid_file: pid_file)

      try do
        assert {:error, %Error{kind: :command_timeout}} =
                 Command.run(["--list-sessions"], cli_command: stub_path, timeout: 100)

        assert TestSupport.wait_until(fn -> File.exists?(pid_file) end, 1_000) == :ok

        pid =
          pid_file
          |> File.read!()
          |> String.trim()
          |> String.to_integer()

        assert TestSupport.wait_until(fn -> not TestSupport.os_process_alive?(pid) end, 5_000) ==
                 :ok
      after
        File.rm_rf(dir)
      end
    end

    test "returns error when explicit CLI path is not found" do
      assert {:error, %Error{kind: :cli_not_found}} =
               Command.run(["--version"], cli_command: "/nonexistent/gemini")
    end

    test "rejects the removed command environment option" do
      removed_option = [:e, :n, :v] |> Enum.join() |> String.to_atom()

      assert {:error, %Error{kind: :invalid_configuration} = error} =
               Command.run(["--version"], [{removed_option, %{}}])

      assert error.message =~ "unsupported command option"
    end

    test "preserves execution_surface over the canonical fake SSH harness" do
      dir = TestSupport.tmp_dir!("gemini_command_fake_ssh")
      stub_path = TestSupport.write_cli_stub!(dir, output: "session list output")
      fake_ssh = FakeSSH.new!()

      try do
        assert {:ok, output} =
                 Command.run(["--list-sessions"],
                   cli_command: stub_path,
                   execution_surface: [
                     surface_kind: :ssh_exec,
                     transport_options:
                       FakeSSH.transport_options(fake_ssh,
                         destination: "gemini-command.test.example",
                         port: 2222
                       )
                   ]
                 )

        assert output =~ "session list output"
        assert FakeSSH.wait_until_written(fake_ssh, 1_000) == :ok

        assert FakeSSH.read_manifest!(fake_ssh) =~ "destination=gemini-command.test.example"
      after
        FakeSSH.cleanup(fake_ssh)
        File.rm_rf(dir)
      end
    end

    test "classifies missing remote Gemini CLI over SSH as :cli_not_found" do
      fake_ssh = FakeSSH.new!()

      try do
        assert {:error, %Error{} = error} =
                 Command.run(["--version"],
                   execution_surface: [
                     surface_kind: :ssh_exec,
                     transport_options:
                       FakeSSH.transport_options(fake_ssh,
                         destination: "gemini-command.missing.example"
                       )
                   ]
                 )

        assert error.kind == :cli_not_found
        assert error.exit_code == 127
        assert error.message =~ "remote target gemini-command.missing.example"
      after
        FakeSSH.cleanup(fake_ssh)
      end
    end
  end
end
