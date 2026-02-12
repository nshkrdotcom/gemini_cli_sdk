defmodule GeminiCliSdk.LiveTest do
  @moduledoc """
  Live integration tests that run against the real Gemini CLI.

  These tests are excluded by default. Run with:

      mix test --only live

  Prerequisites:
    - Gemini CLI installed (`gemini --version` works)
    - Authenticated (`gemini auth login`)
  """
  use ExUnit.Case, async: false

  alias GeminiCliSdk.{Error, Options, Types}

  @moduletag :live

  @live_timeout_ms 120_000

  describe "version/0" do
    test "returns the CLI version string" do
      assert {:ok, version} = GeminiCliSdk.version()
      assert is_binary(version)
      assert byte_size(version) > 0
    end
  end

  describe "run/2" do
    test "returns a response for a simple prompt" do
      opts = %Options{timeout_ms: @live_timeout_ms}

      assert {:ok, response} = GeminiCliSdk.run("Say exactly: LIVE_TEST_OK", opts)
      assert is_binary(response)
      assert byte_size(response) > 0
    end

    test "respects model option" do
      opts = %Options{
        model: "gemini-2.5-flash",
        timeout_ms: @live_timeout_ms
      }

      assert {:ok, response} = GeminiCliSdk.run("Say exactly: FLASH_OK", opts)
      assert is_binary(response)
    end
  end

  describe "execute/2" do
    test "streams typed events for a simple prompt" do
      opts = %Options{timeout_ms: @live_timeout_ms}

      events =
        GeminiCliSdk.execute("Say hello in one word", opts)
        |> Enum.to_list()

      assert length(events) >= 2

      # Should start with an init event
      assert %Types.InitEvent{} = hd(events)

      # Should end with a result event
      assert %Types.ResultEvent{status: "success"} = List.last(events)

      # Should have at least one assistant message
      assistant_msgs =
        Enum.filter(events, &match?(%Types.MessageEvent{role: "assistant"}, &1))

      assert length(assistant_msgs) >= 1
    end

    test "stream can be halted early without error" do
      opts = %Options{timeout_ms: @live_timeout_ms}

      # Take just the first event and verify cleanup doesn't crash
      events =
        GeminiCliSdk.execute("Write a long essay about Elixir", opts)
        |> Enum.take(1)

      assert length(events) == 1
    end

    test "collects stats in result event" do
      opts = %Options{timeout_ms: @live_timeout_ms}

      events =
        GeminiCliSdk.execute("Say hi", opts)
        |> Enum.to_list()

      result = List.last(events)
      assert %Types.ResultEvent{status: "success", stats: stats} = result

      if stats do
        assert stats.total_tokens > 0
      end
    end
  end

  describe "list_sessions/0" do
    test "returns session list without error" do
      assert {:ok, output} = GeminiCliSdk.list_sessions()
      assert is_binary(output)
    end
  end

  describe "error cases" do
    test "timeout produces error" do
      # Very short timeout should fail
      opts = %Options{timeout_ms: 1}

      result = GeminiCliSdk.run("Explain quantum computing in detail", opts)

      assert {:error, %Error{}} = result
    end
  end
end
