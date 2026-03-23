defmodule GeminiCliSdk.TransportTest do
  use ExUnit.Case, async: false

  alias GeminiCliSdk.Transport

  defp sh_path, do: System.find_executable("sh") || "sh"

  test "top-level transport entrypoint preserves Gemini tagged subscriber events" do
    ref = make_ref()

    {:ok, _transport} =
      Transport.start(
        command: sh_path(),
        args: ["-c", "printf 'hello\\n'"],
        subscriber: {self(), ref}
      )

    assert_receive {:gemini_sdk_transport, ^ref, {:message, "hello"}}, 2_000
    assert_receive {:gemini_sdk_transport, ^ref, {:exit, _reason}}, 2_000
  end
end
