defmodule BettingEngine.Repo do
  use Ecto.Repo,
    otp_app: :betting_engine,
    adapter: Ecto.Adapters.Postgres
end
