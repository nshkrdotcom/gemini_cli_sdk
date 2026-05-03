defmodule GeminiCliSdkTest do
  use ExUnit.Case, async: false

  alias GeminiCliSdk.{Error, Options, TestSupport, Types}

  describe "execute/2" do
    test "returns typed event stream from JSONL" do
      dir = TestSupport.tmp_dir!("gemini_api_execute")
      fixture = TestSupport.fixture_path("simple_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture)

      try do
        events =
          GeminiCliSdk.execute("hello", %Options{cli_command: stub_path, timeout_ms: 5_000})
          |> Enum.to_list()

        assert length(events) >= 3
        assert %Types.InitEvent{} = hd(events)
        assert %Types.ResultEvent{status: "success"} = List.last(events)
      after
        File.rm_rf(dir)
      end
    end

    test "propagates timeout as error event" do
      dir = TestSupport.tmp_dir!("gemini_api_timeout")
      stub_path = TestSupport.write_cli_stub!(dir, block?: true)

      try do
        events =
          GeminiCliSdk.execute("wait", %Options{cli_command: stub_path, timeout_ms: 100})
          |> Enum.to_list()

        assert events != []
        last = List.last(events)
        assert %Types.ErrorEvent{} = last
        assert last.message =~ "Timed out"
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "run/2" do
    test "returns collected assistant text on success" do
      dir = TestSupport.tmp_dir!("gemini_api_run")
      fixture = TestSupport.fixture_path("simple_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture)

      try do
        assert {:ok, result} =
                 GeminiCliSdk.run("hello", %Options{cli_command: stub_path, timeout_ms: 5_000})

        assert is_binary(result)
        assert result =~ "Hello"
      after
        File.rm_rf(dir)
      end
    end

    test "returns error on CLI failure with fatal error event" do
      dir = TestSupport.tmp_dir!("gemini_api_run_error")
      fixture = TestSupport.fixture_path("error_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture, exit_code: 41)

      try do
        assert {:error, %Error{}} =
                 GeminiCliSdk.run("bad prompt", %Options{
                   cli_command: stub_path,
                   timeout_ms: 5_000
                 })
      after
        File.rm_rf(dir)
      end
    end

    test "returns auth_error when the stream emits a fatal authentication event" do
      dir = TestSupport.tmp_dir!("gemini_api_run_status_error")
      fixture = TestSupport.fixture_path("error_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture)

      try do
        assert {:error, %Error{kind: :auth_error}} =
                 GeminiCliSdk.run("bad prompt", %Options{
                   cli_command: stub_path,
                   timeout_ms: 5_000
                 })
      after
        File.rm_rf(dir)
      end
    end

    test "does not atomize provider-authored fatal error kind strings" do
      dir = TestSupport.tmp_dir!("gemini_api_unknown_error_kind")
      fixture = Path.join(dir, "unknown_error.jsonl")

      File.write!(
        fixture,
        Jason.encode!(%{
          type: "error",
          severity: "fatal",
          message: "provider invented failure",
          kind: "provider-invented-kind"
        }) <> "\n"
      )

      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture)

      try do
        assert {:error, %Error{kind: :command_failed} = error} =
                 GeminiCliSdk.run("bad prompt", %Options{
                   cli_command: stub_path,
                   timeout_ms: 5_000
                 })

        assert error.context.details["kind"] == "provider-invented-kind"
      after
        File.rm_rf(dir)
      end
    end

    test "returns error when explicit CLI path is not found" do
      assert {:error, %Error{}} =
               GeminiCliSdk.run("hello", %Options{
                 cli_command: "/nonexistent/gemini",
                 timeout_ms: 5_000
               })
    end
  end

  describe "session operations" do
    test "list_sessions/1 returns session list output" do
      dir = TestSupport.tmp_dir!("gemini_api_sessions")

      stub_path =
        TestSupport.write_cli_stub!(dir,
          output: "Available sessions (2):\n  1. Fix bug [abc123]\n  2. Refactor [def456]"
        )

      try do
        assert {:ok, output} = GeminiCliSdk.list_sessions(cli_command: stub_path)
        assert output =~ "abc123"
        assert output =~ "def456"
      after
        File.rm_rf(dir)
      end
    end

    test "list_session_entries/1 parses typed session entries" do
      dir = TestSupport.tmp_dir!("gemini_api_session_entries")

      stub_path =
        TestSupport.write_cli_stub!(dir,
          output: "Available sessions (2):\n  1. Fix bug [abc123]\n  2. Refactor [def456]"
        )

      try do
        assert {:ok, sessions} = GeminiCliSdk.list_session_entries(cli_command: stub_path)

        assert [%GeminiCliSdk.Session.Entry{} = first, %GeminiCliSdk.Session.Entry{} = second] =
                 sessions

        assert first.id == "abc123"
        assert first.label == "Fix bug"
        assert first.index == 1
        assert second.id == "def456"
        assert second.label == "Refactor"
        assert second.index == 2
      after
        File.rm_rf(dir)
      end
    end

    test "list_session_entries/1 parses bracketed labels with fixed parsing" do
      dir = TestSupport.tmp_dir!("gemini_api_session_entries_brackets")

      stub_path =
        TestSupport.write_cli_stub!(dir,
          output: "Available sessions (2):\n  12. Fix [draft] label [sess-12]\n  not a session"
        )

      try do
        assert {:ok, [%GeminiCliSdk.Session.Entry{} = session]} =
                 GeminiCliSdk.list_session_entries(cli_command: stub_path)

        assert session.id == "sess-12"
        assert session.label == "Fix [draft] label"
        assert session.index == 12
      after
        File.rm_rf(dir)
      end
    end

    test "resume_session/3 preserves the resume identifier on the shared runtime lane" do
      dir = TestSupport.tmp_dir!("gemini_api_resume_session")
      args_file = Path.join(dir, "args.txt")
      fixture = TestSupport.fixture_path("simple_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, args_file: args_file, stream_file: fixture)

      try do
        events =
          GeminiCliSdk.resume_session(
            "abc123",
            %Options{cli_command: stub_path, timeout_ms: 5_000},
            "Continue"
          )
          |> Enum.to_list()

        assert %Types.InitEvent{} = hd(events)

        args = File.read!(args_file)
        assert args =~ "--resume"
        assert args =~ "abc123"
        assert args =~ "--prompt"
        assert args =~ "Continue"
      after
        File.rm_rf(dir)
      end
    end

    test "delete_session/2 passes identifier to CLI" do
      dir = TestSupport.tmp_dir!("gemini_api_delete_session")
      args_file = Path.join(dir, "args.txt")

      stub_path =
        TestSupport.write_cli_stub!(dir,
          args_file: args_file,
          output: "Session deleted"
        )

      try do
        assert {:ok, _} = GeminiCliSdk.delete_session("2", cli_command: stub_path)
        args = File.read!(args_file)
        assert args =~ "--delete-session"
        assert args =~ "2"
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "version/0" do
    test "returns CLI version string" do
      dir = TestSupport.tmp_dir!("gemini_api_version")
      stub_path = TestSupport.write_cli_stub!(dir, output: "gemini-cli 1.2.3")

      try do
        assert {:ok, output} = GeminiCliSdk.version(cli_command: stub_path)
        assert output =~ "1.2.3"
      after
        File.rm_rf(dir)
      end
    end
  end
end
