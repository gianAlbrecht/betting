defmodule BettingEngine.Sync.Poller do
  @moduledoc """
  GenServer that triggers periodic odds syncs.

  On startup (and then every `poll_interval_ms`), it starts a concurrent
  sync of all configured leagues via LeaguePipeline.sync_leagues/1.

  Tracks whether a sync is currently running to prevent overlap — if a
  scheduled poll fires while a previous sync is still in progress, the poll
  is skipped and the next interval is scheduled as normal.

  A manual sync can be triggered at any time via `BettingEngine.Sync.Poller.sync_now/1`.
  """

  use GenServer

  require Logger

  alias BettingEngine.Sync.LeaguePipeline

  # ─── Public API ──────────────────────────────────────────

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Trigger an immediate sync. Pass `force: true` to bypass cache."
  @spec sync_now(keyword()) :: :ok
  def sync_now(opts \\ []) do
    GenServer.cast(__MODULE__, {:sync_now, opts})
  end

  # ─── Callbacks ───────────────────────────────────────────

  @impl GenServer
  def init(_opts) do
    case Application.get_env(:betting_engine, :odds_api_key) do
      nil -> Logger.error("[Poller] *** THE_ODDS_API_KEY IS NOT SET — syncs will fail! ***")
      key -> Logger.info("[Poller] API key configured (#{String.length(key)} chars)")
    end

    leagues = Application.get_env(:betting_engine, :leagues, [])
    Logger.info("[Poller] #{length(leagues)} leagues configured")

    Process.send_after(self(), :poll, 5_000)
    Logger.info("[Poller] Started. First sync in 5 seconds.")
    {:ok, %{syncing: false}}
  end

  @impl GenServer
  def handle_info(:poll, %{syncing: true} = state) do
    Logger.warning("[Poller] Skipping scheduled poll — previous sync still in progress")
    schedule_next_poll()
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:poll, state) do
    do_sync(force: false)
    schedule_next_poll()
    {:noreply, %{state | syncing: true}}
  end

  @impl GenServer
  def handle_info(:sync_task_done, state) do
    {:noreply, %{state | syncing: false}}
  end

  @impl GenServer
  def handle_cast({:sync_now, opts}, state) do
    if state.syncing do
      Logger.warning("[Poller] sync_now called but a sync is already running — ignoring")
    else
      do_sync(opts)
    end

    {:noreply, %{state | syncing: true}}
  end

  # ─── Private ─────────────────────────────────────────────

  defp do_sync(opts) do
    leagues = Application.get_env(:betting_engine, :leagues, [])
    force = Keyword.get(opts, :force, false)

    Logger.info("[Poller] #{if force, do: "Force sync", else: "Scheduled sync"} — #{length(leagues)} leagues")

    tagged = Enum.map(leagues, &Map.put(&1, :force, force))

    Phoenix.PubSub.broadcast(
      BettingEngine.PubSub,
      "sync:status",
      {:sync_started, %{leagues: length(leagues), force: force}}
    )

    caller = self()

    # Run in background so the Poller GenServer stays responsive.
    # The `after` block always fires — even on crash — so the Poller's
    # `syncing` flag is reliably cleared regardless of outcome.
    Task.Supervisor.start_child(BettingEngine.TaskSupervisor, fn ->
      try do
        LeaguePipeline.sync_leagues(tagged)
      rescue
        e ->
          Logger.error("[Poller] Sync crashed: #{Exception.message(e)}")

          Phoenix.PubSub.broadcast(
            BettingEngine.PubSub,
            "sync:status",
            {:sync_error, %{league: "all", error: Exception.message(e)}}
          )

          Phoenix.PubSub.broadcast(BettingEngine.PubSub, "sync:status", {:sync_complete, %{}})
      after
        send(caller, :sync_task_done)
      end
    end)
  end

  defp schedule_next_poll do
    interval =
      Application.get_env(:betting_engine, :sync, [])[:poll_interval_ms] ||
        6 * 60 * 60 * 1_000

    Process.send_after(self(), :poll, interval)
    Logger.info("[Poller] Next sync in #{div(interval, 60_000)} minutes")
  end
end
