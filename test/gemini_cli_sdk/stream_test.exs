defmodule GeminiCliSdk.StreamTest do
  use ExUnit.Case, async: false

  alias GeminiCliSdk.TestSupport
  alias GeminiCliSdk.Types

  defp write_stream_stub!(dir) do
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

    if [ -n "${GEMINI_TEST_STDERR:-}" ]; then
      echo "$GEMINI_TEST_STDERR" >&2
    fi

    exit_code="${GEMINI_TEST_EXIT_CODE:-0}"

    if [ -n "${GEMINI_TEST_STREAM_FILE:-}" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        echo "$line"
      done < "$GEMINI_TEST_STREAM_FILE"
      exit "$exit_code"
    fi

    if [ -n "${GEMINI_TEST_OUTPUT:-}" ]; then
      echo "$GEMINI_TEST_OUTPUT"
      exit "$exit_code"
    fi

    exit "$exit_code"
    """

    TestSupport.write_executable!(dir, "gemini", script)
  end

  describe "simple prompt -> stream of events" do
    test "returns stream of typed events from JSONL output" do
      dir = TestSupport.tmp_dir!("gemini_stream_simple")
      stub_path = write_stream_stub!(dir)
      fixture = TestSupport.fixture_path("simple_response.jsonl")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          events =
            GeminiCliSdk.Stream.execute("hello", %GeminiCliSdk.Options{
              timeout_ms: 5_000,
              env: %{"GEMINI_TEST_STREAM_FILE" => fixture}
            })
            |> Enum.to_list()

          assert length(events) >= 3

          [init | rest] = events
          assert %Types.InitEvent{} = init

          result = List.last(rest)
          assert %Types.ResultEvent{status: "success"} = result
        end)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "tool use/result event sequences" do
    test "streams tool_use and tool_result events in order" do
      dir = TestSupport.tmp_dir!("gemini_stream_tools")
      stub_path = write_stream_stub!(dir)
      fixture = TestSupport.fixture_path("tool_use_response.jsonl")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          events =
            GeminiCliSdk.Stream.execute("list files", %GeminiCliSdk.Options{
              timeout_ms: 5_000,
              env: %{"GEMINI_TEST_STREAM_FILE" => fixture}
            })
            |> Enum.to_list()

          tool_uses = Enum.filter(events, &match?(%Types.ToolUseEvent{}, &1))
          tool_results = Enum.filter(events, &match?(%Types.ToolResultEvent{}, &1))

          assert tool_uses != []
          assert tool_results != []

          use_idx = Enum.find_index(events, &match?(%Types.ToolUseEvent{}, &1))
          result_idx = Enum.find_index(events, &match?(%Types.ToolResultEvent{}, &1))
          assert use_idx < result_idx
        end)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "error event handling" do
    test "streams error events from CLI" do
      dir = TestSupport.tmp_dir!("gemini_stream_error")
      stub_path = write_stream_stub!(dir)
      fixture = TestSupport.fixture_path("error_response.jsonl")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          events =
            GeminiCliSdk.Stream.execute("bad prompt", %GeminiCliSdk.Options{
              timeout_ms: 5_000,
              env: %{
                "GEMINI_TEST_STREAM_FILE" => fixture,
                "GEMINI_TEST_EXIT_CODE" => "41"
              }
            })
            |> Enum.to_list()

          error_events = Enum.filter(events, &match?(%Types.ErrorEvent{}, &1))
          assert error_events != []
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "transport exit includes structured stderr and exit_code details" do
      dir = TestSupport.tmp_dir!("gemini_stream_structured_exit")
      stub_path = write_stream_stub!(dir)

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          events =
            GeminiCliSdk.Stream.execute("bad prompt", %GeminiCliSdk.Options{
              timeout_ms: 5_000,
              env: %{
                "GEMINI_TEST_STDERR" => "fatal auth error",
                "GEMINI_TEST_EXIT_CODE" => "41"
              }
            })
            |> Enum.to_list()

          assert events != []
          last = List.last(events)
          assert %Types.ErrorEvent{severity: "fatal", kind: :transport_exit, exit_code: 41} = last
          assert last.message =~ "code 41"
          assert last.stderr == "fatal auth error"
          assert is_map(last.details)
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "transport exit caps stderr tail and marks truncation" do
      dir = TestSupport.tmp_dir!("gemini_stream_truncated_stderr")
      stub_path = write_stream_stub!(dir)

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          events =
            GeminiCliSdk.Stream.execute("bad prompt", %GeminiCliSdk.Options{
              timeout_ms: 5_000,
              max_stderr_buffer_bytes: 16,
              env: %{
                "GEMINI_TEST_STDERR" => "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                "GEMINI_TEST_EXIT_CODE" => "7"
              }
            })
            |> Enum.to_list()

          assert events != []
          last = List.last(events)

          assert %Types.ErrorEvent{kind: :transport_exit, exit_code: 7, stderr_truncated?: true} =
                   last

          assert is_binary(last.stderr)
          assert byte_size(last.stderr) <= 16
          assert String.ends_with?(last.stderr, "QRSTUVWXYZ")
        end)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "timeout handling" do
    test "emits timeout error when mock CLI blocks" do
      dir = TestSupport.tmp_dir!("gemini_stream_timeout")
      stub_path = write_stream_stub!(dir)

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          events =
            GeminiCliSdk.Stream.execute("wait forever", %GeminiCliSdk.Options{
              timeout_ms: 100,
              env: %{"GEMINI_TEST_BLOCK" => "1"}
            })
            |> Enum.to_list()

          assert events != []
          last = List.last(events)
          assert %Types.ErrorEvent{} = last
          assert last.message =~ "Timed out"
        end)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "stream cancellation" do
    test "halting the stream early cleans up the OS process" do
      dir = TestSupport.tmp_dir!("gemini_stream_cancel")
      pid_file = Path.join(dir, "pid.txt")
      stub_path = write_stream_stub!(dir)
      fixture = TestSupport.fixture_path("multi_turn.jsonl")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          [first_event] =
            GeminiCliSdk.Stream.execute("hello", %GeminiCliSdk.Options{
              timeout_ms: 5_000,
              env: %{
                "GEMINI_TEST_STREAM_FILE" => fixture,
                "GEMINI_TEST_PID_FILE" => pid_file
              }
            })
            |> Enum.take(1)

          assert %Types.InitEvent{} = first_event

          if File.exists?(pid_file) do
            pid = pid_file |> File.read!() |> String.trim() |> String.to_integer()

            assert TestSupport.wait_until(
                     fn -> not TestSupport.os_process_alive?(pid) end,
                     5_000
                   ) == :ok
          end
        end)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "selective receive (mailbox safety)" do
    test "does not consume unrelated mailbox messages" do
      dir = TestSupport.tmp_dir!("gemini_stream_mailbox")
      stub_path = write_stream_stub!(dir)
      marker = make_ref()
      fixture = TestSupport.fixture_path("simple_response.jsonl")

      send(self(), {:unrelated_message, marker})

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          _events =
            GeminiCliSdk.Stream.execute("hello", %GeminiCliSdk.Options{
              timeout_ms: 5_000,
              env: %{"GEMINI_TEST_STREAM_FILE" => fixture}
            })
            |> Enum.to_list()

          assert_received {:unrelated_message, ^marker}
        end)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "CLI not found" do
    test "emits error event when CLI not found" do
      TestSupport.with_env(
        %{"GEMINI_CLI_PATH" => "/nonexistent/gemini", "PATH" => "/nonexistent_dir_only"},
        fn ->
          events =
            GeminiCliSdk.Stream.execute("hello", %GeminiCliSdk.Options{timeout_ms: 5_000})
            |> Enum.to_list()

          assert length(events) == 1
          assert %Types.ErrorEvent{severity: "fatal"} = hd(events)
        end
      )
    end
  end
end
