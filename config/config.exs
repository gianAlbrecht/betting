import Config

config :betting_engine, ecto_repos: [BettingEngine.Repo]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :module, :league, :sport]

config :phoenix, :json_library, Jason

config :esbuild, :version, "0.25.0"

config :esbuild,
  betting_web: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/betting_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind, :version, "4.1.12"

config :tailwind,
  betting_web: [
    args: ~w(--input=css/app.css --output=../priv/static/assets/app.css),
    cd: Path.expand("../apps/betting_web/assets", __DIR__)
  ]

config :betting_engine, :pubsub, name: BettingEngine.PubSub

config :betting_web, BettingWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: BettingEngine.PubSub

config :betting_engine, :sync,
  poll_interval_ms: 6 * 60 * 60 * 1_000,
  delay_between_calls_ms: 1_000,
  monthly_request_limit: 500

config :betting_engine, :leagues, [
  %{
    key: "soccer_epl",
    name: "Premier League",
    sport_slug: "football",
    sport_name: "Football",
    api_sports_league_id: 39
  },
  %{
    key: "soccer_germany_bundesliga",
    name: "Bundesliga",
    sport_slug: "football",
    sport_name: "Football",
    api_sports_league_id: 78
  },
  %{
    key: "soccer_spain_la_liga",
    name: "La Liga",
    sport_slug: "football",
    sport_name: "Football",
    api_sports_league_id: 140
  },
  %{
    key: "soccer_italy_serie_a",
    name: "Serie A",
    sport_slug: "football",
    sport_name: "Football",
    api_sports_league_id: 135
  },
  %{
    key: "soccer_france_ligue_one",
    name: "Ligue 1",
    sport_slug: "football",
    sport_name: "Football",
    api_sports_league_id: 61
  },
  %{
    key: "soccer_uefa_champs_league",
    name: "Champions League",
    sport_slug: "football",
    sport_name: "Football",
    api_sports_league_id: 2
  },
  %{
    key: "soccer_uefa_europa_league",
    name: "Europa League",
    sport_slug: "football",
    sport_name: "Football",
    api_sports_league_id: 3
  },
  %{
    key: "soccer_uefa_europa_conference_league",
    name: "Conference League",
    sport_slug: "football",
    sport_name: "Football",
    api_sports_league_id: 848
  },
  %{
    key: "soccer_switzerland_superleague",
    name: "Swiss Super League",
    sport_slug: "football",
    sport_name: "Football",
    api_sports_league_id: 207
  },
  %{
    key: "icehockey_nhl",
    name: "NHL",
    sport_slug: "icehockey",
    sport_name: "Ice Hockey",
    api_sports_league_id: 57
  },
  %{
    key: "icehockey_sweden_hockey_league",
    name: "SHL",
    sport_slug: "icehockey",
    sport_name: "Ice Hockey",
    api_sports_league_id: 66
  },
  %{
    key: "icehockey_liiga",
    name: "Liiga",
    sport_slug: "icehockey",
    sport_name: "Ice Hockey",
    api_sports_league_id: 52
  }
]

import_config "#{config_env()}.exs"
