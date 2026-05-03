defmodule GeminiCliSdk.GovernedLaunchTest do
  use ExUnit.Case, async: false

  alias GeminiCliSdk.{Command, Error, GovernedLaunch, Options, Runtime.CLI, TestSupport}

  describe "governed command launch" do
    test "uses authority command and env instead of CLI discovery or native login" do
      dir = TestSupport.tmp_dir!("gemini_governed_command")
      command = authority_env_echo!(dir)

      try do
        authority = governed_authority(command, env: %{"GEMINI_AUTHORITY_TOKEN" => "lease-token"})

        assert {:ok, "lease-token"} =
                 Command.run(["ignored"], governed_authority: authority)
      after
        File.rm_rf(dir)
      end
    end

    test "rejects explicit CLI command smuggling" do
      dir = TestSupport.tmp_dir!("gemini_governed_command_smuggling")
      command = authority_env_echo!(dir)

      try do
        authority = governed_authority(command)

        assert {:error, %Error{kind: :invalid_configuration} = error} =
                 Command.run(["ignored"],
                   governed_authority: authority,
                   cli_command: "/tmp/unmanaged-gemini"
                 )

        assert error.message =~ "governed"
        assert error.message =~ "cli_command"
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "governed session launch" do
    test "uses authority command, cwd, env, and clear env for sessions" do
      dir = TestSupport.tmp_dir!("gemini_governed_session")
      command = TestSupport.write_cli_stub!(dir, block?: true)
      cwd = Path.join(dir, "target")
      File.mkdir_p!(cwd)
      monitor_ref = make_ref()

      try do
        authority =
          governed_authority(command,
            cwd: cwd,
            env: %{"GEMINI_AUTHORITY_TOKEN" => "session-token"}
          )

        options = Options.validate!(%Options{governed_authority: authority})

        assert {:ok, session, %{info: info}} =
                 CLI.start_session(
                   prompt: "hello",
                   options: options,
                   subscriber: {self(), monitor_ref}
                 )

        assert info.invocation.command == command
        assert info.invocation.cwd == cwd
        assert info.invocation.env == %{"GEMINI_AUTHORITY_TOKEN" => "session-token"}
        assert info.invocation.clear_env? == true

        session_monitor = Process.monitor(session)
        assert :ok = CLI.close(session)
        assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, 2_000
      after
        File.rm_rf(dir)
      end
    end

    test "invalid authority fails closed without CLI discovery fallback" do
      options = %Options{
        governed_authority: [
          authority_ref: "authority-only",
          credential_lease_ref: "lease-only"
        ]
      }

      assert {:error, reason} = CLI.start_session(prompt: "hello", options: options)
      assert inspect(reason) =~ "governed"
    end
  end

  describe "governed option validation" do
    test "rejects cwd, CLI command, and settings config-root smuggling" do
      dir = TestSupport.tmp_dir!("gemini_governed_option_smuggling")
      command = TestSupport.write_cli_stub!(dir)
      authority = governed_authority(command)

      try do
        for {field, value} <- [
              cli_command: command,
              cwd: dir,
              settings: %{"theme" => "unmanaged"}
            ] do
          options = struct!(Options, [{:governed_authority, authority}, {field, value}])

          assert {:error, {:governed_launch_smuggling, ^field}} =
                   GovernedLaunch.validate_options(options)
        end
      after
        File.rm_rf(dir)
      end
    end

    test "rejects model payload env overrides" do
      dir = TestSupport.tmp_dir!("gemini_governed_model_payload")
      command = TestSupport.write_cli_stub!(dir)

      try do
        options = %Options{
          governed_authority: governed_authority(command),
          model_payload: %{env_overrides: %{"GEMINI_AUTHORITY_TOKEN" => "unmanaged"}}
        }

        assert {:error, {:governed_launch_smuggling, :model_payload, :env_overrides}} =
                 GovernedLaunch.validate_options(options)
      after
        File.rm_rf(dir)
      end
    end

    test "preserves standalone explicit command compatibility" do
      dir = TestSupport.tmp_dir!("gemini_standalone_command")
      command = TestSupport.write_cli_stub!(dir, output: "standalone-ok")

      try do
        assert {:ok, "standalone-ok"} = Command.run(["ignored"], cli_command: command)
      after
        File.rm_rf(dir)
      end
    end
  end

  defp governed_authority(command, opts \\ []) do
    [
      authority_ref: "authority:gemini:test",
      credential_lease_ref: "lease:gemini:test",
      target_ref: "target:gemini:test",
      command: command,
      cwd: Keyword.get(opts, :cwd),
      env: Keyword.get(opts, :env, %{}),
      clear_env?: true,
      config_root: Keyword.get(opts, :config_root),
      auth_root: Keyword.get(opts, :auth_root),
      base_url: Keyword.get(opts, :base_url),
      command_ref: "command:gemini:test",
      redaction_ref: "redaction:gemini:test"
    ]
  end

  defp authority_env_echo!(dir) do
    TestSupport.write_executable!(
      dir,
      "gemini-authority",
      """
      #!/bin/sh
      printf '%s\\n' "$GEMINI_AUTHORITY_TOKEN"
      """
    )
  end
end
