defmodule GeminiCliSdk.Runtime.CLITest do
  use ExUnit.Case, async: false

  alias CliSubprocessCore.{Event, Payload, ProcessExit}
  alias CliSubprocessCore.TestSupport.FakeSSH
  alias GeminiCliSdk.{Options, Runtime.CLI, TestSupport, Types}

  defp write_runtime_stub!(dir) do
    TestSupport.write_cli_stub!(dir, block?: true)
  end

  defp write_list_stub!(dir) do
    TestSupport.write_cli_stub!(dir,
      output: "Available sessions (2):\n  1. Fix bug [abc123]\n  2. Refactor [def456]"
    )
  end

  describe "start_session/1" do
    test "builds a core session with Gemini-compatible invocation args" do
      dir = TestSupport.tmp_dir!("gemini_runtime_cli")
      stub_path = write_runtime_stub!(dir)
      monitor_ref = make_ref()

      try do
        options = %Options{
          cli_command: stub_path,
          model: "gemini-2.5-pro",
          approval_mode: :plan,
          sandbox: true,
          skip_trust: true,
          resume: "abc123",
          extensions: ["ext1", "ext2"],
          include_directories: ["src", "docs"],
          allowed_tools: ["Bash", "Read"],
          allowed_mcp_server_names: ["github", "jira"],
          debug: true,
          settings: %{"theme" => "test"},
          system_prompt: "Be concise."
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
        assert info.invocation.cwd == temp_dir
        assert info.invocation.env == %{}

        settings_path = Path.join([temp_dir, ".gemini", "settings.json"])
        assert File.exists?(settings_path)

        args = info.invocation.args

        assert "--prompt" in args

        assert Enum.at(args, Enum.find_index(args, &(&1 == "--prompt")) + 1) =~
                 "Be concise.\n\nhello"

        assert "--output-format" in args
        assert "--model" in args
        assert "--approval-mode" in args
        assert "--sandbox" in args
        assert "--skip-trust" in args
        assert "--resume" in args
        assert "--include-directories" in args
        assert "--allowed-tools" in args
        assert "--allowed-mcp-server-names" in args
        assert "--debug" in args
        refute "--settings-file" in args

        extension_indices =
          args
          |> Enum.with_index()
          |> Enum.filter(fn {value, _index} -> value == "--extensions" end)
          |> Enum.map(fn {_value, index} -> index end)

        assert length(extension_indices) == 2
        assert Enum.map(extension_indices, &Enum.at(args, &1 + 1)) == ["ext1", "ext2"]

        session_monitor = Process.monitor(session)
        assert :ok = CLI.close(session)
        assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, 2_000

        File.rm_rf!(temp_dir)
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
        options =
          Options.validate!(%Options{
            cli_command: stub_path,
            execution_surface: [
              surface_kind: :ssh_exec,
              transport_options:
                FakeSSH.transport_options(fake_ssh,
                  destination: "gemini-runtime.test.example",
                  port: 2222
                )
            ]
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
        options =
          Options.validate!(%Options{
            cli_command: stub_path,
            execution_surface: [
              surface_kind: :ssh_exec,
              transport_options:
                FakeSSH.transport_options(fake_ssh, destination: "gemini-runtime.cwd.example")
            ]
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
      after
        FakeSSH.cleanup(fake_ssh)
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
        assert {:ok, [first, second]} = CLI.list_provider_sessions(cli_command: stub_path)
        assert first.id == "abc123"
        assert first.label == "Fix bug"
        assert first.source_kind == :cli_history
        assert first.metadata.index == 1
        assert second.id == "def456"
        assert second.label == "Refactor"
        assert second.metadata.index == 2
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
          raw: %{exit: ProcessExit.from_reason(:normal)},
          payload: Payload.Result.new(status: :completed)
        )

      assert {[exit_failure], _state} = CLI.project_event(exit_result, exit_state)

      assert %Types.ErrorEvent{severity: "fatal", kind: :transport_exit, exit_code: 0} =
               exit_failure

      assert exit_failure.message =~ "code 0"
    end
  end

  describe "render_for_test/1" do
    test "renders Gemini-native flags and settings without resolving or spawning the CLI" do
      {:ok, render} =
        CLI.render_for_test(
          prompt: "return ok",
          execution_surface: [
            surface_kind: :local_subprocess,
            observability: %{suite: :promotion_path}
          ],
          options: %Options{
            model: "gemini-3.1-flash-lite-preview",
            approval_mode: :plan,
            skip_trust: true,
            extensions: ["none"],
            allowed_tools: ["Read"],
            allowed_mcp_server_names: ["docs"],
            settings: GeminiCliSdk.SettingsProfiles.plain_response()
          }
        )

      assert render.provider == :gemini
      assert render.execution_surface.observability == %{suite: :promotion_path}
      assert render.settings["tools"]["core"] == []
      assert render.provider_native.extensions == ["none"]
      assert render.provider_native.allowed_tools == ["Read"]
      assert render.provider_native.allowed_mcp_server_names == ["docs"]

      args = render.args
      assert flag_value(args, "--prompt") == "return ok"
      assert flag_value(args, "--model") == "gemini-3.1-flash-lite-preview"
      assert flag_value(args, "--approval-mode") == "plan"
      assert flag_value(args, "--extensions") == "none"
      assert flag_value(args, "--allowed-tools") == "Read"
      assert flag_value(args, "--allowed-mcp-server-names") == "docs"
      assert "--skip-trust" in args
    end
  end

  defp flag_value(args, flag) do
    case Enum.find_index(args, &(&1 == flag)) do
      nil -> nil
      idx -> Enum.at(args, idx + 1)
    end
  end
end
