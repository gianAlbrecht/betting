defmodule BettingEngine.Application do
  @moduledoc """
  OTP Application entry point for the betting_engine umbrella child.

  Starts the supervision tree in dependency order:
    1. Repo           — Ecto/PostgreSQL connection pool
    2. PubSub         — Phoenix PubSub hub shared by all LiveViews and sync modules
    3. TaskSupervisor — Dynamic task pool for concurrent HTTP fetches (LeaguePipeline)
                        and heavy background work (parlay generation, results sync)
    4. Sync.Supervisor — Contains the Poller GenServer that drives periodic syncs

  After the supervisor tree is up, runs all pending Ecto migrations automatically.
  This means Docker containers and fresh deployments need no manual migration step.
  Disabled in the test environment via the :auto_migrate config key to avoid
  interfering with the test DB setup.
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      BettingEngine.Repo,

      {Phoenix.PubSub, name: BettingEngine.PubSub},

      {Task.Supervisor, name: BettingEngine.TaskSupervisor},

      BettingEngine.Sync.Supervisor
    ]

    opts = [strategy: :one_for_one, name: BettingEngine.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      maybe_migrate()
      {:ok, pid}
    end
  end

  defp maybe_migrate do
    if Application.get_env(:betting_engine, :auto_migrate, true) do
      migrate()
    end
  end

  defp migrate do
    path = Application.app_dir(:betting_engine, "priv/repo/migrations")

    Ecto.Migrator.with_repo(BettingEngine.Repo, fn repo ->
      Ecto.Migrator.run(repo, path, :up, all: true)
    end)
    |> case do
      {:ok, migrations, _} when migrations != [] ->
        Logger.info("[App] Ran #{length(migrations)} migration(s)")

      {:ok, [], _} ->
        Logger.debug("[App] Migrations: already up to date")

      {:error, reason} ->
        Logger.error("[App] Migration failed: #{inspect(reason)}")
    end
  end
end
