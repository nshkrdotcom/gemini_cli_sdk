defmodule GeminiCliSdk.TypesTest do
  use ExUnit.Case, async: true

  alias GeminiCliSdk.{Error, Models, Types}

  describe "parse_event/1" do
    test "parses init event" do
      json =
        Jason.encode!(%{
          type: "init",
          session_id: "abc123",
          model: Models.default_model(),
          timestamp: "2026-02-11T12:00:00.000Z"
        })

      assert {:ok, %Types.InitEvent{} = event} = Types.parse_event(json)
      assert event.session_id == "abc123"
      assert event.model == Models.default_model()
    end

    test "parses message event with role=user" do
      json =
        Jason.encode!(%{
          type: "message",
          role: "user",
          content: "What is 2+2?",
          timestamp: "2026-02-11T12:00:01.000Z"
        })

      assert {:ok, %Types.MessageEvent{role: "user", content: "What is 2+2?"}} =
               Types.parse_event(json)
    end

    test "parses message event with role=assistant and delta flag" do
      json =
        Jason.encode!(%{
          type: "message",
          role: "assistant",
          content: "The answer is 4.",
          delta: true,
          timestamp: "2026-02-11T12:00:02.000Z"
        })

      assert {:ok, %Types.MessageEvent{role: "assistant", delta: true}} =
               Types.parse_event(json)
    end

    test "parses tool_use event" do
      json =
        Jason.encode!(%{
          type: "tool_use",
          tool_name: "Bash",
          tool_id: "bash-123",
          parameters: %{command: "ls -la"},
          timestamp: "2026-02-11T12:00:03.000Z"
        })

      assert {:ok, %Types.ToolUseEvent{} = event} = Types.parse_event(json)
      assert event.tool_name == "Bash"
      assert event.tool_id == "bash-123"
      assert event.parameters == %{"command" => "ls -la"}
    end

    test "parses tool_result event with success" do
      json =
        Jason.encode!(%{
          type: "tool_result",
          tool_id: "bash-123",
          status: "success",
          output: "file1.txt\nfile2.txt",
          timestamp: "2026-02-11T12:00:04.000Z"
        })

      assert {:ok, %Types.ToolResultEvent{status: "success", output: output}} =
               Types.parse_event(json)

      assert output =~ "file1.txt"
    end

    test "parses tool_result event with error" do
      json =
        Jason.encode!(%{
          type: "tool_result",
          tool_id: "bash-456",
          status: "error",
          error: "command not found",
          timestamp: "2026-02-11T12:00:05.000Z"
        })

      assert {:ok, %Types.ToolResultEvent{status: "error", error: "command not found"}} =
               Types.parse_event(json)
    end

    test "parses error event" do
      json =
        Jason.encode!(%{
          type: "error",
          severity: "fatal",
          message: "Authentication failed",
          kind: "transport_exit",
          exit_code: 41,
          stderr: "auth failed",
          stderr_truncated: true,
          details: %{"reason" => "exit_status"},
          timestamp: "2026-02-11T12:00:06.000Z"
        })

      assert {:ok,
              %Types.ErrorEvent{
                severity: "fatal",
                message: "Authentication failed",
                kind: "transport_exit",
                exit_code: 41,
                stderr: "auth failed",
                stderr_truncated?: true,
                details: %{"reason" => "exit_status"}
              }} =
               Types.parse_event(json)
    end

    test "parses result event with stats" do
      json =
        Jason.encode!(%{
          type: "result",
          status: "success",
          stats: %{
            total_tokens: 250,
            input_tokens: 50,
            output_tokens: 200,
            duration_ms: 3000,
            tool_calls: 1
          },
          timestamp: "2026-02-11T12:00:07.000Z"
        })

      assert {:ok, %Types.ResultEvent{} = event} = Types.parse_event(json)
      assert event.status == "success"
      assert event.stats.duration_ms == 3000
      assert event.stats.tool_calls == 1
    end

    test "returns error for malformed JSON" do
      assert {:error, %Error{kind: :json_decode_error}} =
               Types.parse_event("{broken json")
    end

    test "returns error for unknown event type" do
      json = Jason.encode!(%{type: "unknown_thing"})

      assert {:error, %Error{kind: :unknown_event_type, cause: "unknown_thing"}} =
               Types.parse_event(json)
    end

    test "returns error for missing type field" do
      json = Jason.encode!(%{foo: "bar"})

      assert {:error, %Error{kind: :invalid_event, cause: :missing_type_field}} =
               Types.parse_event(json)
    end

    test "preserves extra fields for forward compatibility" do
      json =
        Jason.encode!(%{
          type: "init",
          session_id: "abc",
          model: Models.default_model(),
          new_future_field: "ignored"
        })

      assert {:ok, %Types.InitEvent{session_id: "abc", extra: %{"new_future_field" => "ignored"}}} =
               Types.parse_event(json)
    end
  end

  describe "final_event?/1" do
    test "ResultEvent is final" do
      assert Types.final_event?(%Types.ResultEvent{})
    end

    test "ErrorEvent with fatal severity is final" do
      assert Types.final_event?(%Types.ErrorEvent{severity: "fatal"})
    end

    test "InitEvent is not final" do
      refute Types.final_event?(%Types.InitEvent{})
    end

    test "MessageEvent is not final" do
      refute Types.final_event?(%Types.MessageEvent{})
    end

    test "ToolUseEvent is not final" do
      refute Types.final_event?(%Types.ToolUseEvent{})
    end
  end
end
