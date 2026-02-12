defmodule GeminiCliSdk.Transport.ErlexecTest do
  use ExUnit.Case, async: false

  alias GeminiCliSdk.Transport.Erlexec

  defp sh_path, do: System.find_executable("sh") || "sh"

  describe "start/stop lifecycle" do
    test "starts transport and receives exit event" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "exit 0"]
        )

      ref = make_ref()
      :ok = Erlexec.subscribe(transport, self(), ref)
      assert_receive {:gemini_sdk_transport, ^ref, {:exit, _reason}}, 2_000
    end

    test "start/1 wraps init failures as tagged transport errors" do
      assert {:error, {:transport, _reason}} =
               Erlexec.start(command: sh_path(), args: ["-c", "echo ok"], subscriber: :bad)
    end
  end

  describe "stdout line buffering" do
    test "streams stdout messages line by line" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "printf 'line1\\nline2\\nline3\\n'"]
        )

      ref = make_ref()
      :ok = Erlexec.subscribe(transport, self(), ref)

      assert_receive {:gemini_sdk_transport, ^ref, {:message, "line1"}}, 2_000
      assert_receive {:gemini_sdk_transport, ^ref, {:message, "line2"}}, 2_000
      assert_receive {:gemini_sdk_transport, ^ref, {:message, "line3"}}, 2_000
      assert_receive {:gemini_sdk_transport, ^ref, {:exit, _reason}}, 2_000
    end

    test "flushes partial line on process exit" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "printf 'no-newline'"]
        )

      ref = make_ref()
      :ok = Erlexec.subscribe(transport, self(), ref)

      assert_receive {:gemini_sdk_transport, ^ref, {:message, "no-newline"}}, 2_000
      assert_receive {:gemini_sdk_transport, ^ref, {:exit, _reason}}, 2_000
    end
  end

  describe "stderr capture" do
    test "captures stderr and emits it" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "echo 'error output' >&2"]
        )

      ref = make_ref()
      :ok = Erlexec.subscribe(transport, self(), ref)

      assert_receive {:gemini_sdk_transport, ^ref, {:stderr, stderr}}, 2_000
      assert stderr =~ "error output"
    end

    test "caps stderr buffer to configured tail size" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "printf '1234567890ABCDEFGHIJ' >&2"],
          max_stderr_buffer_size: 8
        )

      ref = make_ref()
      :ok = Erlexec.subscribe(transport, self(), ref)

      assert_receive {:gemini_sdk_transport, ^ref, {:stderr, stderr}}, 2_000
      assert byte_size(stderr) <= 8
    end
  end

  describe "exit code propagation" do
    test "propagates non-zero exit code" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "exit 42"]
        )

      ref = make_ref()
      :ok = Erlexec.subscribe(transport, self(), ref)

      assert_receive {:gemini_sdk_transport, ^ref, {:exit, {:exit_status, exit_status}}}, 2_000
      # erlexec may encode exit status as code * 256
      assert exit_status == 42 or exit_status == 42 * 256
    end
  end

  describe "subscriber management" do
    test "re-subscribing same pid updates the tag" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "echo hello"]
        )

      ref1 = make_ref()
      ref2 = make_ref()
      :ok = Erlexec.subscribe(transport, self(), ref1)
      # Re-subscribing same PID replaces the tag
      :ok = Erlexec.subscribe(transport, self(), ref2)

      # Messages arrive with the latest tag (ref2)
      assert_receive {:gemini_sdk_transport, ^ref2, {:message, "hello"}}, 2_000
    end
  end

  describe "graceful shutdown" do
    test "close/1 terminates the transport" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "sleep 10"]
        )

      monitor_ref = Process.monitor(transport)
      assert :ok = Erlexec.close(transport)
      assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _}, 2_000
    end
  end

  describe "force_close/1" do
    test "kills the transport" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "sleep 10"]
        )

      monitor_ref = Process.monitor(transport)
      assert :ok = Erlexec.force_close(transport)
      assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _}, 2_000
    end
  end

  describe "end_input/1" do
    test "sends EOF to stdin-driven commands" do
      cat = System.find_executable("cat") || "cat"

      {:ok, transport} = Erlexec.start(command: cat, args: [])
      ref = make_ref()
      :ok = Erlexec.subscribe(transport, self(), ref)

      assert :ok = Erlexec.send(transport, "echo me")
      assert :ok = Erlexec.end_input(transport)

      assert_receive {:gemini_sdk_transport, ^ref, {:message, "echo me"}}, 2_000
      assert_receive {:gemini_sdk_transport, ^ref, {:exit, _reason}}, 2_000
    end
  end

  describe "post-exit behavior" do
    test "returns typed not_connected errors after transport exits" do
      {:ok, transport} =
        Erlexec.start(
          command: sh_path(),
          args: ["-c", "exit 0"]
        )

      monitor_ref = Process.monitor(transport)
      assert_receive {:DOWN, ^monitor_ref, :process, ^transport, _reason}, 2_000

      assert {:error, {:transport, _}} = Erlexec.send(transport, "echo me")
      assert {:error, {:transport, _}} = Erlexec.end_input(transport)
      assert :disconnected = Erlexec.status(transport)
    end
  end
end
