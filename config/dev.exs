import Config

config :betting_engine, BettingEngine.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: System.get_env("DB_NAME", "betting_dev"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :betting_web, :dev_routes, true

config :betting_web, BettingWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "hCU++PjIY/A9ByYxJULrwpViC/ZuVLoehlrIxszgYRp7ymLTQWxfmbPSDeRsogoI",
  live_view: [signing_salt: "YwBf25hrwzYN1nRn6jS61Kl5M3myUnlN"],
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:betting_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:betting_web, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"apps/betting_web/priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"apps/betting_web/lib/betting_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :betting_engine, :sync,
  poll_interval_ms: 30 * 60 * 1_000,
  delay_between_calls_ms: 1_000,
  monthly_request_limit: 500
