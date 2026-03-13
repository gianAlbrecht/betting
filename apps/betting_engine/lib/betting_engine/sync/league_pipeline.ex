defmodule BettingEngine.Sync.LeaguePipeline do
  @moduledoc """
  Fetches and persists odds for multiple leagues concurrently.

  Called by Poller with a list of league configs. Runs up to @concurrency (3)
  HTTP fetches in parallel via Task.Supervisor.async_stream_nolink. The nolink
  variant is important: a crashed or timed-out task does not take down the
  pipeline — the error is logged and all other leagues continue unaffected.

  Flow per league:
    1. Optional throttle delay (delay_between_calls_ms config) to stay within
       API rate limits when many leagues are synced in quick succession.
    2. OddsApi.Client.fetch_odds/2 → hits The Odds API or returns {:cached, n}
       if a successful sync already exists within the last 6 hours.
    3. SportsSync.upsert_league_events/2 → writes fixtures + odds to the DB.
    4. PubSub broadcast on "odds:updated" so analysis LiveViews can refresh.

  After all leagues finish (or fail), a single {:sync_complete, %{}} is
  broadcast on "sync:status". Poller uses this to clear its syncing flag and
  the dashboard uses it to reload stats exactly once per sync cycle.
  """

  require Logger

  alias BettingEngine.Sync.SportsSync
  alias BettingEngine.OddsApi.Client, as: OddsClient

  @concurrency 3
  @task_timeout_ms 40_000

  def sync_leagues(league_configs) do
    BettingEngine.TaskSupervisor
    |> Task.Supervisor.async_stream_nolink(
      league_configs,
      &fetch_and_upsert/1,
      max_concurrency: @concurrency,
      timeout: @task_timeout_ms,
      on_timeout: :kill_task
    )
    |> Stream.each(fn
      {:ok, _} ->
        :ok

      {:exit, reason} ->
        Logger.error("[LeaguePipeline] Task exited unexpectedly: #{inspect(reason)}")
    end)
    |> Stream.run()

    Phoenix.PubSub.broadcast(BettingEngine.PubSub, "sync:status", {:sync_complete, %{}})
    :ok
  end

  defp fetch_and_upsert(league_config) do
    Logger.metadata(league: league_config.name, sport: league_config.sport_slug)
    Logger.info("[LeaguePipeline] Fetching #{league_config.name}")

    maybe_delay()

    case OddsClient.fetch_odds(league_config, force: Map.get(league_config, :force, false)) do
      {:ok, events, _rate_limit} ->
        Logger.info("[LeaguePipeline] Got #{length(events)} events for #{league_config.name}")
        upsert_and_broadcast(league_config, events)

      {:cached, count} ->
        Logger.info(
          "[LeaguePipeline] Cache hit for #{league_config.name} (#{count} fixtures, skipping)"
        )

      {:error, reason} ->
        Logger.error("[LeaguePipeline] Fetch failed for #{league_config.name}: #{reason}")
    end
  end

  defp upsert_and_broadcast(league_config, events) do
    case SportsSync.upsert_league_events(league_config, events) do
      {:ok, stats} ->
        Logger.info(
          "[LeaguePipeline] Upserted #{stats.fixtures} fixtures, #{stats.odds} odds for #{league_config.name}"
        )

        Phoenix.PubSub.broadcast(
          BettingEngine.PubSub,
          "odds:updated",
          {:odds_updated, %{league: league_config.name, stats: stats}}
        )

      {:error, reason} ->
        Logger.error(
          "[LeaguePipeline] DB upsert failed for #{league_config.name}: #{inspect(reason)}"
        )

        Phoenix.PubSub.broadcast(
          BettingEngine.PubSub,
          "sync:status",
          {:sync_error, %{league: league_config.name, error: "DB error: #{inspect(reason)}"}}
        )
    end
  end

  defp maybe_delay do
    delay = Application.get_env(:betting_engine, :sync, [])[:delay_between_calls_ms] || 0

    if delay > 0 do
      Process.sleep(delay)
    end
  end
end
