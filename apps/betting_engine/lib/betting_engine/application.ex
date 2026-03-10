defmodule BettingEngine.Application do
  @moduledoc """
  The BettingEngine OTP application.

  Starts:
    - BettingEngine.Repo (Ecto / PostgreSQL)
    - BettingEngine.PubSub (Phoenix.PubSub)
    - BettingEngine.TaskSupervisor (for fire-and-forget tasks)
    - BettingEngine.Sync.Supervisor (OddsPoller + Broadway pipeline)
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # 1. Database connection pool
      BettingEngine.Repo,

      # 2. PubSub — must start before any LiveView or broadcaster
      {Phoenix.PubSub, name: BettingEngine.PubSub},

      # 3. Task.Supervisor for short-lived concurrent tasks
      {Task.Supervisor, name: BettingEngine.TaskSupervisor},

      # 4. Sync subsystem: Broadway pipeline + periodic poller
      BettingEngine.Sync.Supervisor
    ]

    opts = [strategy: :one_for_one, name: BettingEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
