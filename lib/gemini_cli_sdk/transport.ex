defmodule GeminiCliSdk.Transport do
  @moduledoc """
  Behaviour and public raw CLI transport entrypoints for Gemini.

  The shared core owns subprocess lifecycle and raw transport behavior; this
  module defines the Gemini-facing surface layered on top.
  """

  alias CliSubprocessCore.Transport, as: CoreTransport
  alias GeminiCliSdk.Configuration
  alias GeminiCliSdk.Error

  @type t :: pid()
  @type message :: binary()
  @type opts :: keyword()
  @type subscription_tag :: reference()

  @event_tag :gemini_sdk_transport

  @callback start(opts()) :: {:ok, t()} | {:error, term()}
  @callback start_link(opts()) :: {:ok, t()} | {:error, term()}
  @callback send(t(), message()) :: :ok | {:error, term()}
  @callback subscribe(t(), pid(), subscription_tag()) :: :ok | {:error, term()}
  @callback close(t()) :: :ok
  @callback force_close(t()) :: :ok | {:error, term()}
  @callback status(t()) :: :connected | :disconnected | :error
  @callback end_input(t()) :: :ok | {:error, term()}
  @callback stderr(t()) :: String.t()

  @spec start(opts()) :: {:ok, t()} | {:error, term()}
  def start(opts) when is_list(opts) do
    CoreTransport.start(normalize_start_opts(opts))
  end

  @spec start_link(opts()) :: {:ok, t()} | {:error, term()}
  def start_link(opts) when is_list(opts) do
    CoreTransport.start_link(normalize_start_opts(opts))
  end

  @spec send(t(), message()) :: :ok | {:error, term()}
  def send(transport, message) when is_pid(transport) do
    CoreTransport.send(transport, message)
  end

  @spec subscribe(t(), pid(), subscription_tag()) :: :ok | {:error, term()}
  def subscribe(transport, pid, tag)
      when is_pid(transport) and is_pid(pid) and is_reference(tag) do
    CoreTransport.subscribe(transport, pid, tag)
  end

  @spec close(t()) :: :ok
  def close(transport) when is_pid(transport) do
    CoreTransport.close(transport)
  end

  @spec force_close(t()) :: :ok | {:error, term()}
  def force_close(transport) when is_pid(transport) do
    CoreTransport.force_close(transport)
  end

  @spec status(t()) :: :connected | :disconnected | :error
  def status(transport) when is_pid(transport) do
    CoreTransport.status(transport)
  end

  @spec end_input(t()) :: :ok | {:error, term()}
  def end_input(transport) when is_pid(transport) do
    CoreTransport.end_input(transport)
  end

  @spec stderr(t()) :: String.t()
  def stderr(transport) when is_pid(transport) do
    CoreTransport.stderr(transport)
  end

  @spec error_to_error(term(), keyword()) :: Error.t()
  def error_to_error(reason, opts \\ []) do
    Error.normalize(reason, Keyword.put_new(opts, :kind, :transport_error))
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
