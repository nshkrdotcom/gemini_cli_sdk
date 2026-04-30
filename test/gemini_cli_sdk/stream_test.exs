defmodule GeminiCliSdk.StreamTest do
  use ExUnit.Case, async: false

  alias CliSubprocessCore.TestSupport.FakeSSH
  alias GeminiCliSdk.{Options, TestSupport, Types}

  describe "simple prompt -> stream of events" do
    test "returns stream of typed events from JSONL output" do
      dir = TestSupport.tmp_dir!("gemini_stream_simple")
      fixture = TestSupport.fixture_path("simple_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture)

      try do
        events =
          GeminiCliSdk.Stream.execute("hello", %Options{
            cli_command: stub_path,
            timeout_ms: 5_000
          })
          |> Enum.to_list()

        assert length(events) >= 3

        [init | rest] = events
        assert %Types.InitEvent{} = init

        result = List.last(rest)
        assert %Types.ResultEvent{status: "success"} = result
      after
        File.rm_rf(dir)
      end
    end

    test "preserves execution_surface over the canonical fake SSH harness" do
      dir = TestSupport.tmp_dir!("gemini_stream_fake_ssh")
      fixture = TestSupport.fixture_path("simple_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture)
      fake_ssh = FakeSSH.new!()

      try do
        events =
          GeminiCliSdk.Stream.execute("hello over ssh", %Options{
            cli_command: stub_path,
            timeout_ms: 5_000,
            execution_surface: [
              surface_kind: :ssh_exec,
              transport_options:
                FakeSSH.transport_options(fake_ssh,
                  destination: "gemini-stream.test.example",
                  port: 2222
                )
            ]
          })
          |> Enum.to_list()

        assert %Types.InitEvent{} = hd(events)
        assert %Types.ResultEvent{status: "success"} = List.last(events)
        assert FakeSSH.wait_until_written(fake_ssh, 1_000) == :ok
        assert FakeSSH.read_manifest!(fake_ssh) =~ "destination=gemini-stream.test.example"
      after
        FakeSSH.cleanup(fake_ssh)
        File.rm_rf(dir)
      end
    end
  end

  describe "tool use/result event sequences" do
    test "streams tool_use and tool_result events in order" do
      dir = TestSupport.tmp_dir!("gemini_stream_tools")
      fixture = TestSupport.fixture_path("tool_use_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture)

      try do
        events =
          GeminiCliSdk.Stream.execute("list files", %Options{
            cli_command: stub_path,
            timeout_ms: 5_000
          })
          |> Enum.to_list()

        tool_uses = Enum.filter(events, &match?(%Types.ToolUseEvent{}, &1))
        tool_results = Enum.filter(events, &match?(%Types.ToolResultEvent{}, &1))

        assert tool_uses != []
        assert tool_results != []

        use_idx = Enum.find_index(events, &match?(%Types.ToolUseEvent{}, &1))
        result_idx = Enum.find_index(events, &match?(%Types.ToolResultEvent{}, &1))
        assert use_idx < result_idx
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "error event handling" do
    test "startup failures preserve the wrapped provider error kind and cause details" do
      missing_path = Path.join(TestSupport.tmp_dir!("gemini_missing_cli"), "missing-gemini")

      events =
        GeminiCliSdk.Stream.execute("hello", %Options{
          cli_command: missing_path,
          timeout_ms: 1_000
        })
        |> Enum.to_list()

      assert [%Types.ErrorEvent{} = event] = events
      assert event.kind == :stream_start_failed
      assert event.message =~ "missing-gemini"
      assert is_map(event.details)
      assert event.details[:underlying_kind] == :cli_not_found
      assert event.details[:cause] in [":missing", "missing"]
    end

    test "streams error events from CLI" do
      dir = TestSupport.tmp_dir!("gemini_stream_error")
      fixture = TestSupport.fixture_path("error_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture, exit_code: 41)

      try do
        events =
          GeminiCliSdk.Stream.execute("bad prompt", %Options{
            cli_command: stub_path,
            timeout_ms: 5_000
          })
          |> Enum.to_list()

        error_events = Enum.filter(events, &match?(%Types.ErrorEvent{}, &1))
        assert error_events != []
      after
        File.rm_rf(dir)
      end
    end

    test "invalid JSON output becomes a fatal parse error event" do
      dir = TestSupport.tmp_dir!("gemini_stream_parse_error")
      fixture_path = Path.join(dir, "broken.jsonl")

      File.write!(fixture_path, """
      {"type":"init","timestamp":"2026-02-11T12:00:00.000Z","session_id":"sess-parse","model":"gemini-2.5-pro"}
      {broken json
      """)

      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture_path)

      try do
        events =
          GeminiCliSdk.Stream.execute("bad output", %Options{
            cli_command: stub_path,
            timeout_ms: 5_000
          })
          |> Enum.to_list()

        assert length(events) == 2
        assert %Types.InitEvent{session_id: "sess-parse"} = hd(events)

        assert %Types.ErrorEvent{severity: "fatal", kind: :parse_error} = List.last(events)
        assert List.last(events).message =~ "JSON parse error"
      after
        File.rm_rf(dir)
      end
    end

    test "transport exit includes structured stderr and exit_code details" do
      dir = TestSupport.tmp_dir!("gemini_stream_structured_exit")
      stub_path = TestSupport.write_cli_stub!(dir, stderr: "fatal auth error", exit_code: 41)

      try do
        events =
          GeminiCliSdk.Stream.execute("bad prompt", %Options{
            cli_command: stub_path,
            timeout_ms: 5_000
          })
          |> Enum.to_list()

        assert events != []
        last = List.last(events)
        assert %Types.ErrorEvent{severity: "fatal", kind: :transport_exit, exit_code: 41} = last
        assert last.message =~ "code 41"
        assert last.stderr == "fatal auth error"
        assert is_map(last.details)
      after
        File.rm_rf(dir)
      end
    end

    test "transport exit caps stderr tail and marks truncation" do
      dir = TestSupport.tmp_dir!("gemini_stream_truncated_stderr")

      stub_path =
        TestSupport.write_cli_stub!(dir,
          stderr: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ",
          exit_code: 7
        )

      try do
        events =
          GeminiCliSdk.Stream.execute("bad prompt", %Options{
            cli_command: stub_path,
            timeout_ms: 5_000,
            max_stderr_buffer_bytes: 16
          })
          |> Enum.to_list()

        assert events != []
        last = List.last(events)

        assert %Types.ErrorEvent{kind: :transport_exit, exit_code: 7, stderr_truncated?: true} =
                 last

        assert is_binary(last.stderr)
        assert byte_size(last.stderr) <= 16
        assert String.ends_with?(last.stderr, "QRSTUVWXYZ")
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "timeout handling" do
    test "emits timeout error when mock CLI blocks" do
      dir = TestSupport.tmp_dir!("gemini_stream_timeout")
      stub_path = TestSupport.write_cli_stub!(dir, block?: true)

      try do
        events =
          GeminiCliSdk.Stream.execute("wait forever", %Options{
            cli_command: stub_path,
            timeout_ms: 100
          })
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

  describe "stream cancellation" do
    test "halting the stream early cleans up the OS process" do
      dir = TestSupport.tmp_dir!("gemini_stream_cancel")
      pid_file = Path.join(dir, "pid.txt")
      fixture = TestSupport.fixture_path("multi_turn.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture, pid_file: pid_file)

      try do
        [first_event] =
          GeminiCliSdk.Stream.execute("hello", %Options{
            cli_command: stub_path,
            timeout_ms: 5_000
          })
          |> Enum.take(1)

        assert %Types.InitEvent{} = first_event

        if File.exists?(pid_file) do
          pid = pid_file |> File.read!() |> String.trim() |> String.to_integer()

          assert TestSupport.wait_until(fn -> not TestSupport.os_process_alive?(pid) end, 5_000) ==
                   :ok
        end
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "selective receive (mailbox safety)" do
    test "does not consume unrelated mailbox messages" do
      dir = TestSupport.tmp_dir!("gemini_stream_mailbox")
      marker = make_ref()
      fixture = TestSupport.fixture_path("simple_response.jsonl")
      stub_path = TestSupport.write_cli_stub!(dir, stream_file: fixture)

      send(self(), {:unrelated_message, marker})

      try do
        _events =
          GeminiCliSdk.Stream.execute("hello", %Options{
            cli_command: stub_path,
            timeout_ms: 5_000
          })
          |> Enum.to_list()

        assert_received {:unrelated_message, ^marker}
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "CLI not found" do
    test "emits error event when explicit CLI path is not found" do
      events =
        GeminiCliSdk.Stream.execute("hello", %Options{
          cli_command: "/nonexistent/gemini",
          timeout_ms: 5_000
        })
        |> Enum.to_list()

      assert length(events) == 1
      assert %Types.ErrorEvent{severity: "fatal"} = hd(events)
    end
  end
end
