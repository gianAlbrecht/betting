defmodule BettingWeb.Router do
  use BettingWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BettingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BettingWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/arbitrage", ArbitrageLive, :index
    live "/value-bets", ValueBetsLive, :index
    live "/parlay-generator", ParlayLive, :index
    live "/portfolio", PortfolioLive, :index
  end

  if Application.compile_env(:betting_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: BettingWeb.Telemetry
    end
  end
end
