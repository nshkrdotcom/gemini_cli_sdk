defmodule GeminiCliSdkTest do
  use ExUnit.Case, async: false

  alias GeminiCliSdk.{Error, Options, TestSupport, Types}

  defp write_api_stub!(dir) do
    script = """
    #!/usr/bin/env bash
    set -euo pipefail

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
    fi

    exit "$exit_code"
    """

    TestSupport.write_executable!(dir, "gemini", script)
  end

  describe "execute/2" do
    test "returns typed event stream from JSONL" do
      dir = TestSupport.tmp_dir!("gemini_api_execute")
      stub_path = write_api_stub!(dir)
      fixture = TestSupport.fixture_path("simple_response.jsonl")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          events =
            GeminiCliSdk.execute("hello", %Options{
              timeout_ms: 5_000,
              env: %{"GEMINI_TEST_STREAM_FILE" => fixture}
            })
            |> Enum.to_list()

          assert length(events) >= 3
          assert %Types.InitEvent{} = hd(events)
          assert %Types.ResultEvent{status: "success"} = List.last(events)
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "propagates timeout as error event" do
      dir = TestSupport.tmp_dir!("gemini_api_timeout")
      stub_path = write_api_stub!(dir)

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          events =
            GeminiCliSdk.execute("wait", %Options{
              timeout_ms: 100,
              env: %{"GEMINI_TEST_BLOCK" => "1"}
            })
            |> Enum.to_list()

          assert length(events) >= 1
          last = List.last(events)
          assert %Types.ErrorEvent{} = last
          assert last.message =~ "Timed out"
        end)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "run/2" do
    test "returns collected assistant text on success" do
      dir = TestSupport.tmp_dir!("gemini_api_run")
      stub_path = write_api_stub!(dir)
      fixture = TestSupport.fixture_path("simple_response.jsonl")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          assert {:ok, result} =
                   GeminiCliSdk.run("hello", %Options{
                     timeout_ms: 5_000,
                     env: %{"GEMINI_TEST_STREAM_FILE" => fixture}
                   })

          assert is_binary(result)
          assert result =~ "Hello"
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "returns error on CLI failure with fatal error event" do
      dir = TestSupport.tmp_dir!("gemini_api_run_error")
      stub_path = write_api_stub!(dir)
      fixture = TestSupport.fixture_path("error_response.jsonl")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          assert {:error, %Error{}} =
                   GeminiCliSdk.run("bad prompt", %Options{
                     timeout_ms: 5_000,
                     env: %{
                       "GEMINI_TEST_STREAM_FILE" => fixture,
                       "GEMINI_TEST_EXIT_CODE" => "41"
                     }
                   })
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "returns error when result status is error" do
      dir = TestSupport.tmp_dir!("gemini_api_run_status_error")
      stub_path = write_api_stub!(dir)
      fixture = TestSupport.fixture_path("error_response.jsonl")

      try do
        TestSupport.with_env(%{"GEMINI_CLI_PATH" => stub_path}, fn ->
          assert {:error, %Error{kind: :command_failed}} =
                   GeminiCliSdk.run("bad prompt", %Options{
                     timeout_ms: 5_000,
                     env: %{"GEMINI_TEST_STREAM_FILE" => fixture}
                   })
        end)
      after
        File.rm_rf(dir)
      end
    end

    test "returns error when CLI not found" do
      TestSupport.with_env(
        %{"GEMINI_CLI_PATH" => "/nonexistent/gemini", "PATH" => "/nonexistent_dir_only"},
        fn ->
          assert {:error, %Error{}} =
                   GeminiCliSdk.run("hello", %Options{timeout_ms: 5_000})
        end
      )
    end
  end

  describe "session operations" do
    test "list_sessions/0 returns session list output" do
      dir = TestSupport.tmp_dir!("gemini_api_sessions")
      stub_path = write_api_stub!(dir)

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_OUTPUT" =>
              "Available sessions (2):\n  1. Fix bug [abc123]\n  2. Refactor [def456]"
          },
          fn ->
            assert {:ok, output} = GeminiCliSdk.list_sessions()
            assert output =~ "abc123"
            assert output =~ "def456"
          end
        )
      after
        File.rm_rf(dir)
      end
    end

    test "delete_session/1 passes identifier to CLI" do
      dir = TestSupport.tmp_dir!("gemini_api_delete_session")
      args_file = Path.join(dir, "args.txt")
      stub_path = write_api_stub!(dir)

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_ARGS_FILE" => args_file,
            "GEMINI_TEST_OUTPUT" => "Session deleted"
          },
          fn ->
            assert {:ok, _} = GeminiCliSdk.delete_session("2")
            args = File.read!(args_file)
            assert args =~ "--delete-session"
            assert args =~ "2"
          end
        )
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "version/0" do
    test "returns CLI version string" do
      dir = TestSupport.tmp_dir!("gemini_api_version")
      stub_path = write_api_stub!(dir)

      try do
        TestSupport.with_env(
          %{
            "GEMINI_CLI_PATH" => stub_path,
            "GEMINI_TEST_OUTPUT" => "gemini-cli 1.2.3"
          },
          fn ->
            assert {:ok, output} = GeminiCliSdk.version()
            assert output =~ "1.2.3"
          end
        )
      after
        File.rm_rf(dir)
      end
    end
  end
end
