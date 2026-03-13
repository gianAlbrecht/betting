defmodule BettingEngine.Application do
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
