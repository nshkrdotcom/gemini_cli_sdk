defmodule GeminiCliSdk.Defaults do
  @moduledoc false

  def command_timeout_ms, do: 60_000
  def stream_timeout_ms, do: 300_000
  def transport_call_timeout_ms, do: 5_000
  def transport_force_close_timeout_ms, do: 500
  def transport_headless_timeout_ms, do: 5_000
  def max_buffer_size, do: 1_048_576
  def max_stderr_buffer_size, do: 262_144
end
