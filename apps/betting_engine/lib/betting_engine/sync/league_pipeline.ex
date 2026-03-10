defmodule BettingEngine.Sync.LeaguePipeline do
  @moduledoc """
  Concurrent odds fetcher using Task.Supervisor.

  Fetches up to `@concurrency` leagues in parallel, upserts results, and
  broadcasts changes via PubSub. Uses `async_stream_nolink` so a single
  league's timeout or API error never crashes the entire pipeline.

  Called directly by OddsPoller — no GenStage producer needed.
  """

  require Logger

  alias BettingEngine.Sync.SportsSync
  alias BettingEngine.OddsApi.Client, as: OddsClient

  @concurrency 3
  # Per-task HTTP + DB timeout. Must exceed OddsClient's 30s receive_timeout.
  @task_timeout_ms 40_000

  @doc """
  Fetch and upsert odds for the given league configs concurrently.
  Returns :ok when all tasks complete (success or failure).
  """
  def sync_leagues(league_configs) do
    league_configs
    |> Task.Supervisor.async_stream_nolink(
      BettingEngine.TaskSupervisor,
      &fetch_and_upsert/1,
      max_concurrency: @concurrency,
      timeout: @task_timeout_ms,
      on_timeout: :kill_task
    )
    |> Stream.each(fn
      {:ok, _} ->
        :ok

      {:exit, reason} ->
        Logger.error("[LeaguePipeline] Task exited unexpectedly",
          reason: inspect(reason)
        )
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

  # Honour the configured inter-call delay to avoid hammering the API.
  defp maybe_delay do
    delay = Application.get_env(:betting_engine, :sync, [])[:delay_between_calls_ms] || 0

    if delay > 0 do
      Process.sleep(delay)
    end
  end
end
