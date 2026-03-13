import Config

if config_env() == :prod do
  database_url =
    System.fetch_env!("DATABASE_URL")

  config :betting_engine, BettingEngine.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    ssl: System.get_env("DB_SSL", "false") == "true"

  secret_key_base =
    System.fetch_env!("SECRET_KEY_BASE")

  config :betting_web, BettingWeb.Endpoint,
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT", "4000"))
    ],
    secret_key_base: secret_key_base

  config :betting_engine, :sync,
    poll_interval_ms:
      System.get_env("POLL_INTERVAL_HOURS", "6")
      |> String.to_integer()
      |> then(&(&1 * 60 * 60 * 1_000)),
    delay_between_calls_ms:
      System.get_env("API_DELAY_MS", "1000") |> String.to_integer(),
    monthly_request_limit:
      System.get_env("MONTHLY_REQUEST_LIMIT", "500") |> String.to_integer()
end

if config_env() != :test do
  config :betting_engine, :odds_api_key, System.fetch_env!("THE_ODDS_API_KEY")

  if key = System.get_env("API_SPORTS_KEY") do
    config :betting_engine, :sports_api_key, key
  end
end
