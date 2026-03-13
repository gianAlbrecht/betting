import Config

config :betting_engine, BettingEngine.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: System.get_env("DB_NAME", "betting_test#{System.get_env("MIX_TEST_PARTITION")}"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :betting_web, BettingWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_replace_in_production_absolutely",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime

config :betting_engine, :sync,
  poll_interval_ms: :infinity,
  delay_between_calls_ms: 0,
  monthly_request_limit: 500

config :betting_engine, :auto_migrate, false
