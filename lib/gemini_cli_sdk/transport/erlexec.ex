defmodule GeminiCliSdk.Transport.Erlexec do
  @moduledoc """
  Gemini raw transport entrypoint backed by `CliSubprocessCore.Transport`.

  This module preserves Gemini's public transport module path while subprocess
  lifecycle and raw transport behavior are owned by the shared core.
  """

  alias CliSubprocessCore.Transport, as: CoreTransport
  alias GeminiCliSdk.Configuration

  @behaviour GeminiCliSdk.Transport

  @event_tag :gemini_sdk_transport

  @impl GeminiCliSdk.Transport
  def start(opts) when is_list(opts) do
    CoreTransport.start(normalize_start_opts(opts))
  end

  @impl GeminiCliSdk.Transport
  def start_link(opts) when is_list(opts) do
    CoreTransport.start_link(normalize_start_opts(opts))
  end

  @impl GeminiCliSdk.Transport
  def send(transport, message) when is_pid(transport) do
    CoreTransport.send(transport, message)
  end

  @impl GeminiCliSdk.Transport
  def subscribe(transport, pid, tag)
      when is_pid(transport) and is_pid(pid) and is_reference(tag) do
    CoreTransport.subscribe(transport, pid, tag)
  end

  @impl GeminiCliSdk.Transport
  def close(transport) when is_pid(transport) do
    CoreTransport.close(transport)
  end

  @impl GeminiCliSdk.Transport
  def force_close(transport) when is_pid(transport) do
    CoreTransport.force_close(transport)
  end

  @impl GeminiCliSdk.Transport
  def status(transport) when is_pid(transport) do
    CoreTransport.status(transport)
  end

  @impl GeminiCliSdk.Transport
  def end_input(transport) when is_pid(transport) do
    CoreTransport.end_input(transport)
  end

  @spec stderr(pid()) :: String.t()
  def stderr(transport) when is_pid(transport) do
    CoreTransport.stderr(transport)
  end

  defp normalize_start_opts(opts) do
    task_supervisor = Keyword.get_lazy(opts, :task_supervisor, &default_task_supervisor/0)

    opts
    |> Keyword.put(:task_supervisor, task_supervisor)
    |> Keyword.put_new(:event_tag, @event_tag)
    |> Keyword.put_new(:replay_stderr_on_subscribe?, true)
    |> Keyword.put_new(:headless_timeout_ms, Configuration.transport_headless_timeout_ms())
  end

  defp default_task_supervisor do
    case Application.ensure_all_started(:gemini_cli_sdk) do
      {:ok, _started_apps} -> GeminiCliSdk.TaskSupervisor
      {:error, _reason} -> CliSubprocessCore.TaskSupervisor
    end
  end
end
