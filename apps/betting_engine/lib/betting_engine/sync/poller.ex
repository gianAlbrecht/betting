defmodule BettingEngine.Sync.Poller do
  use GenServer

  require Logger

  import Ecto.Query

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.Fixture
  alias BettingEngine.Sync.{LeaguePipeline, ResultsSync}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

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
