defmodule BettingEngine.Sync.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = [
      BettingEngine.Sync.Poller
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
