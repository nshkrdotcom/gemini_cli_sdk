defmodule GeminiCliSdk.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: GeminiCliSdk.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: GeminiCliSdk.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
