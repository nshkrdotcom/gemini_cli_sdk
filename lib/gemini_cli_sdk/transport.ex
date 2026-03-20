defmodule GeminiCliSdk.Transport do
  @moduledoc """
  Behaviour and thin public facade for raw CLI transport access.
  """

  alias GeminiCliSdk.Error
  alias GeminiCliSdk.Transport.Erlexec

  @type t :: pid()
  @type message :: binary()
  @type opts :: keyword()
  @type subscription_tag :: reference()

  @callback start(opts()) :: {:ok, t()} | {:error, term()}
  @callback start_link(opts()) :: {:ok, t()} | {:error, term()}
  @callback send(t(), message()) :: :ok | {:error, term()}
  @callback subscribe(t(), pid(), subscription_tag()) :: :ok | {:error, term()}
  @callback close(t()) :: :ok
  @callback force_close(t()) :: :ok | {:error, term()}
  @callback status(t()) :: :connected | :disconnected | :error
  @callback end_input(t()) :: :ok | {:error, term()}

  @spec start(opts()) :: {:ok, t()} | {:error, term()}
  def start(opts), do: Erlexec.start(opts)

  @spec start_link(opts()) :: {:ok, t()} | {:error, term()}
  def start_link(opts), do: Erlexec.start_link(opts)

  @spec send(t(), message()) :: :ok | {:error, term()}
  def send(transport, message), do: Erlexec.send(transport, message)

  @spec subscribe(t(), pid(), subscription_tag()) :: :ok | {:error, term()}
  def subscribe(transport, pid, tag), do: Erlexec.subscribe(transport, pid, tag)

  @spec close(t()) :: :ok
  def close(transport), do: Erlexec.close(transport)

  @spec force_close(t()) :: :ok | {:error, term()}
  def force_close(transport), do: Erlexec.force_close(transport)

  @spec status(t()) :: :connected | :disconnected | :error
  def status(transport), do: Erlexec.status(transport)

  @spec end_input(t()) :: :ok | {:error, term()}
  def end_input(transport), do: Erlexec.end_input(transport)

  @spec error_to_error(term(), keyword()) :: Error.t()
  def error_to_error(reason, opts \\ []) do
    Error.normalize(reason, Keyword.put_new(opts, :kind, :transport_error))
  end
end
