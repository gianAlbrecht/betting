defmodule BettingUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        betting_umbrella: [
          applications: [betting_engine: :permanent, betting_web: :permanent]
        ]
      ]
    ]
  end

  defp deps do
    []
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run apps/betting_engine/priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "phx.routes": "phx.routes BettingWeb.Router",
      "assets.build": ["tailwind betting_web", "esbuild betting_web"],
      "assets.deploy": ["tailwind betting_web --minify", "esbuild betting_web --minify", "phx.digest"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
