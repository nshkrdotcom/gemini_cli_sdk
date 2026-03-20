defmodule GeminiCliSdk.Transport.Erlexec do
  @moduledoc """
  Thin compatibility wrapper around `CliSubprocessCore.Transport.Erlexec`.
  """

  alias CliSubprocessCore.Transport.Erlexec, as: CoreErlexec

  @behaviour GeminiCliSdk.Transport

  @event_tag :gemini_sdk_transport

  @impl GeminiCliSdk.Transport
  def start(opts) when is_list(opts) do
    CoreErlexec.start(normalize_start_opts(opts))
  end

  @impl GeminiCliSdk.Transport
  def start_link(opts) when is_list(opts) do
    CoreErlexec.start_link(normalize_start_opts(opts))
  end

  @impl GeminiCliSdk.Transport
  def send(transport, message) when is_pid(transport) do
    CoreErlexec.send(transport, message)
  end

  @impl GeminiCliSdk.Transport
  def subscribe(transport, pid, tag)
      when is_pid(transport) and is_pid(pid) and is_reference(tag) do
    CoreErlexec.subscribe(transport, pid, tag)
  end

  @impl GeminiCliSdk.Transport
  def close(transport) when is_pid(transport) do
    CoreErlexec.close(transport)
  end

  @impl GeminiCliSdk.Transport
  def force_close(transport) when is_pid(transport) do
    CoreErlexec.force_close(transport)
  end

  @impl GeminiCliSdk.Transport
  def status(transport) when is_pid(transport) do
    CoreErlexec.status(transport)
  end

  @impl GeminiCliSdk.Transport
  def end_input(transport) when is_pid(transport) do
    CoreErlexec.end_input(transport)
  end

  @spec stderr(pid()) :: String.t()
  def stderr(transport) when is_pid(transport) do
    CoreErlexec.stderr(transport)
  end

  defp normalize_start_opts(opts) do
    Keyword.put_new(opts, :event_tag, @event_tag)
  end
end
