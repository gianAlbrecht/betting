defmodule BettingWeb.Application do
  @moduledoc "Phoenix web application."
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BettingWeb.Telemetry,
      BettingWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: BettingWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BettingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
