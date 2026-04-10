defmodule GeminiCliSdk.Runtime.CLITest do
  use ExUnit.Case, async: false

  alias CliSubprocessCore.{Event, Payload}
  alias CliSubprocessCore.TestSupport.FakeSSH
  alias ExecutionPlane.ProcessExit
  alias GeminiCliSdk.{Options, Runtime.CLI, TestSupport, Types}

  defp write_runtime_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail
    sleep 60
    """

    TestSupport.write_executable!(dir, "gemini", script)
  end

  defp write_list_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%s\n' 'Available sessions (2):' '  1. Fix bug [abc123]' '  2. Refactor [def456]'
    """

    TestSupport.write_executable!(dir, "gemini", script)
  end

  describe "start_session/1" do
    test "builds a core session with Gemini-compatible invocation args and env" do
      dir = TestSupport.tmp_dir!("gemini_runtime_cli")
      stub_path = write_runtime_stub!(dir)
      monitor_ref = make_ref()

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          options = %Options{
            model: "gemini-2.5-pro",
            approval_mode: :plan,
            sandbox: true,
            resume: "abc123",
            extensions: ["ext1", "ext2"],
            include_directories: ["src", "docs"],
            allowed_tools: ["Bash", "Read"],
            allowed_mcp_server_names: ["github", "jira"],
            debug: true,
            settings: %{"theme" => "test"},
            system_prompt: "Be concise.",
            env: %{"GEMINI_TEST_RUNTIME" => "1"}
          }

          assert {:ok, session, %{info: info, temp_dir: temp_dir}} =
                   CLI.start_session(
                     prompt: "hello",
                     options: options,
                     subscriber: {self(), monitor_ref}
                   )

          assert info.provider == :gemini
          assert info.runtime.provider == :gemini
          assert info.invocation.command == stub_path
          assert info.invocation.cwd == File.cwd!()
          assert info.invocation.env["GEMINI_TEST_RUNTIME"] == "1"
          assert info.invocation.env["GEMINI_SYSTEM_MD"] == "Be concise."

          args = info.invocation.args

          assert "--prompt" in args
          assert "--output-format" in args
          assert "--model" in args
          assert "--approval-mode" in args
          assert "--sandbox" in args
          assert "--resume" in args
          assert "--include-directories" in args
          assert "--allowed-tools" in args
          assert "--allowed-mcp-server-names" in args
          assert "--debug" in args

          extension_indices =
            args
            |> Enum.with_index()
            |> Enum.filter(fn {value, _index} -> value == "--extensions" end)
            |> Enum.map(fn {_value, index} -> index end)

          assert length(extension_indices) == 2
          assert Enum.map(extension_indices, &Enum.at(args, &1 + 1)) == ["ext1", "ext2"]

          settings_idx = Enum.find_index(args, &(&1 == "--settings-file"))
          assert is_integer(settings_idx)

          settings_path = Enum.at(args, settings_idx + 1)
          assert is_binary(settings_path)
          assert File.exists?(settings_path)
          assert String.starts_with?(settings_path, temp_dir)

          session_monitor = Process.monitor(session)
          assert :ok = CLI.close(session)
          assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, 2_000

          File.rm_rf!(temp_dir)
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "preserves execution_surface over the canonical fake SSH harness" do
      dir = TestSupport.tmp_dir!("gemini_runtime_cli_fake_ssh")
      stub_path = write_runtime_stub!(dir)
      fake_ssh = FakeSSH.new!()
      monitor_ref = make_ref()

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          options =
            Options.validate!(%Options{
              execution_surface: [
                surface_kind: :ssh_exec,
                transport_options:
                  FakeSSH.transport_options(fake_ssh,
                    destination: "gemini-runtime.test.example",
                    port: 2222
                  )
              ],
              env: %{
                "GEMINI_TEST_RUNTIME" => "1",
                "PATH" => dir <> ":" <> (System.get_env("PATH") || "")
              }
            })

          assert {:ok, session, %{info: info}} =
                   CLI.start_session(
                     prompt: "hello over ssh",
                     options: options,
                     subscriber: {self(), monitor_ref}
                   )

          assert info.delivery.tagged_event_tag == CLI.session_event_tag()
          assert info.transport.info.surface_kind == :ssh_exec

          assert info.transport.info.delivery.tagged_event_tag ==
                   :cli_subprocess_core_session_transport

          assert FakeSSH.wait_until_written(fake_ssh, 1_000) == :ok
          assert FakeSSH.read_manifest!(fake_ssh) =~ "destination=gemini-runtime.test.example"

          session_monitor = Process.monitor(session)
          assert :ok = CLI.close(session)
          assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, 2_000
        end)
      after
        FakeSSH.cleanup(fake_ssh)
        File.rm_rf(dir)
      end
    end

    test "does not leak the local cwd into remote session invocations" do
      dir = TestSupport.tmp_dir!("gemini_runtime_cli_remote_cwd")
      stub_path = write_runtime_stub!(dir)
      fake_ssh = FakeSSH.new!()
      monitor_ref = make_ref()

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          options =
            Options.validate!(%Options{
              execution_surface: [
                surface_kind: :ssh_exec,
                transport_options:
                  FakeSSH.transport_options(fake_ssh, destination: "gemini-runtime.cwd.example")
              ],
              env: %{"PATH" => dir <> ":" <> (System.get_env("PATH") || "")}
            })

          assert {:ok, session, %{info: info}} =
                   CLI.start_session(
                     prompt: "hello over ssh",
                     options: options,
                     subscriber: {self(), monitor_ref}
                   )

          assert info.invocation.cwd == nil

          session_monitor = Process.monitor(session)
          assert :ok = CLI.close(session)
          assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, 2_000
        end)
      after
        FakeSSH.cleanup(fake_ssh)
        File.rm_rf(dir)
      end
    end

    test "does not leak the local cwd into guest-path session invocations" do
      dir = TestSupport.tmp_dir!("gemini_runtime_cli_guest_cwd")
      monitor_ref = make_ref()
      _stub_path = write_runtime_stub!(dir)
      path_env = dir <> ":" <> (System.get_env("PATH") || "")

      try do
        TestSupport.with_env(%{"PATH" => path_env}, fn ->
          options =
            Options.validate!(%Options{
              execution_surface: [surface_kind: :test_guest_local],
              env: %{"PATH" => path_env}
            })

          assert {:ok, session, %{info: info}} =
                   CLI.start_session(
                     prompt: "hello over guest path semantics",
                     options: options,
                     subscriber: {self(), monitor_ref}
                   )

          assert info.invocation.cwd == nil

          session_monitor = Process.monitor(session)
          assert :ok = CLI.close(session)
          assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, 2_000
        end)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "transport wrapper deletion sequencing" do
    test "records zero surviving Gemini transport wrapper behavior on the active runtime lane" do
      refute File.exists?(Path.expand("../../lib/gemini_cli_sdk/transport.ex", __DIR__))
    end
  end

  describe "session control surfaces" do
    test "capabilities publish session control support" do
      assert :session_history in CLI.capabilities()
      assert :session_resume in CLI.capabilities()
      assert :session_pause in CLI.capabilities()
      assert :session_intervene in CLI.capabilities()
    end

    test "list_provider_sessions/1 returns standardized Gemini session entries" do
      dir = TestSupport.tmp_dir!("gemini_runtime_session_entries")
      stub_path = write_list_stub!(dir)

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_OUTPUT" =>
              "Available sessions (2):\n  1. Fix bug [abc123]\n  2. Refactor [def456]"
          },
          fn ->
            assert {:ok, [first, second]} = CLI.list_provider_sessions()
            assert first.id == "abc123"
            assert first.label == "Fix bug"
            assert first.source_kind == :cli_history
            assert first.metadata.index == 1
            assert second.id == "def456"
            assert second.label == "Refactor"
            assert second.metadata.index == 2
          end
        )
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "project_event/2" do
    test "drops synthetic session events and projects Gemini raw events back to public structs" do
      state = CLI.new_projection_state()

      run_started =
        Event.new(:run_started,
          payload: Payload.RunStarted.new(command: "gemini", args: ["--prompt", "hello"])
        )

      init_raw = %{"type" => "init", "session_id" => "sess-123", "model" => "gemini-2.5-pro"}

      init_event =
        Event.new(:raw,
          raw: init_raw,
          payload: Payload.Raw.new(stream: :stdout, content: init_raw)
        )

      assert {[], ^state} = CLI.project_event(run_started, state)

      assert {[projected_init], state} = CLI.project_event(init_event, state)
      assert %Types.InitEvent{session_id: "sess-123", model: "gemini-2.5-pro"} = projected_init

      message_raw = %{
        "type" => "message",
        "role" => "assistant",
        "content" => "Hello",
        "delta" => true
      }

      message_event =
        Event.new(:assistant_delta,
          raw: message_raw,
          payload: Payload.AssistantDelta.new(content: "Hello")
        )

      assert {[projected_message], state} = CLI.project_event(message_event, state)

      assert %Types.MessageEvent{role: "assistant", content: "Hello", delta: true} =
               projected_message

      result_raw = %{"type" => "result", "status" => "success", "stats" => %{"input_tokens" => 1}}

      result_event =
        Event.new(:result,
          raw: result_raw,
          payload: Payload.Result.new(status: :completed)
        )

      assert {[projected_result], _state} = CLI.project_event(result_event, state)
      assert %Types.ResultEvent{status: "success"} = projected_result
    end

    test "projects core parse and exit failures to Gemini error events" do
      state = CLI.new_projection_state()

      parse_error =
        Event.new(:error,
          raw: "{broken json",
          payload:
            Payload.Error.new(
              message: "unexpected byte at position 1",
              code: "parse_error",
              metadata: %{line: "{broken json"}
            )
        )

      assert {[parse_failure], _state} = CLI.project_event(parse_error, state)
      assert %Types.ErrorEvent{severity: "fatal", kind: :parse_error} = parse_failure
      assert parse_failure.message =~ "JSON parse error"

      exit_state = CLI.new_projection_state()

      exit_result =
        Event.new(:result,
          raw: %{exit: %ProcessExit{status: :success, code: 0, reason: :normal}},
          payload: Payload.Result.new(status: :completed)
        )

      assert {[exit_failure], _state} = CLI.project_event(exit_result, exit_state)

      assert %Types.ErrorEvent{severity: "fatal", kind: :transport_exit, exit_code: 0} =
               exit_failure

      assert exit_failure.message =~ "code 0"
    end
  end
end
