defmodule BettingEngine.Sync.Poller do
  @moduledoc """
  GenServer that drives all periodic data synchronisation.

  Two independent timers run inside this process:
    :poll          — triggers an odds sync via LeaguePipeline every
                     poll_interval_ms (30 min dev / 6 h prod).
    :results_sync  — triggers ResultsSync every 2 hours to fetch finished
                     scores from API-Sports and settle open bets.

  Overlap prevention: the state tracks syncing: boolean. If a scheduled :poll
  fires while a previous sync is still running, it is skipped and the next
  interval is scheduled normally. This prevents request pile-up when a sync
  takes longer than the poll interval (unlikely but possible on slow networks).

  First-run behaviour: if the fixture table is empty (fresh install / new
  Docker volume), the initial odds sync starts immediately at 0ms delay instead
  of waiting 5 seconds — so the first page load is not blank.

  Manual trigger: BettingEngine.Sync.Poller.sync_now/1 can be called from IEx
  or the dashboard. Accepts `force: true` to bypass the 6-hour cache.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.Fixture
  alias BettingEngine.Sync.{LeaguePipeline, ResultsSync}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Trigger an immediate sync. Pass `force: true` to bypass the 6-hour cache."
  @spec sync_now(keyword()) :: :ok
  def sync_now(opts \\ []) do
    GenServer.cast(__MODULE__, {:sync_now, opts})
  end

  @impl GenServer
  def init(_opts) do
    case Application.get_env(:betting_engine, :odds_api_key) do
      nil -> Logger.error("[Poller] *** THE_ODDS_API_KEY IS NOT SET — syncs will fail! ***")
      key -> Logger.info("[Poller] API key configured (#{String.length(key)} chars)")
    end

    leagues = Application.get_env(:betting_engine, :leagues, [])
    Logger.info("[Poller] #{length(leagues)} leagues configured")

    initial_delay = initial_sync_delay_ms()
    Process.send_after(self(), :poll, initial_delay)
    # Results sync uses a separate timer and runs independently of odds polling.
    # The 60-second head start lets the app fully boot before hitting external APIs.
    Process.send_after(self(), :results_sync, 60_000)
    Logger.info("[Poller] Started. First odds sync in #{div(initial_delay, 1_000)}s, first results sync in 60s.")
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
  def handle_info(:results_sync, state) do
    Task.Supervisor.start_child(BettingEngine.TaskSupervisor, fn ->
      try do
        ResultsSync.sync_results()
      rescue
        e -> Logger.error("[Poller] Results sync crashed: #{Exception.message(e)}")
      end
    end)

    Process.send_after(self(), :results_sync, 2 * 60 * 60 * 1_000)
    {:noreply, state}
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

    # Run in a supervised task so the Poller GenServer stays responsive during
    # the sync (which can take 30–40 seconds for 12 leagues). The `after` block
    # is guaranteed to run even if the task crashes, ensuring the syncing flag
    # is always cleared and the Poller never gets stuck in a locked state.
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

  # If the fixture table is empty, skip the warmup delay and sync immediately
  # so the UI has data on first page load. Falls back to 5s on DB errors so a
  # connection failure at startup doesn't cause a crash loop.
  defp initial_sync_delay_ms do
    count = Repo.one(from(f in Fixture, select: count()))
    if count == 0, do: 0, else: 5_000
  rescue
    _ -> 5_000
  end

  defp schedule_next_poll do
    interval =
      Application.get_env(:betting_engine, :sync, [])[:poll_interval_ms] ||
        6 * 60 * 60 * 1_000

    Process.send_after(self(), :poll, interval)
    Logger.info("[Poller] Next sync in #{div(interval, 60_000)} minutes")
  end
end
