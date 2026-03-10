defmodule BettingWeb.DashboardLive do
  use BettingWeb, :live_view

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.{Fixture, Odd, Sport, ApiSyncLog}
  alias BettingEngine.OddsApi.Client, as: OddsClient
  import Ecto.Query

  @league_count 12

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BettingEngine.PubSub, "odds:updated")
      Phoenix.PubSub.subscribe(BettingEngine.PubSub, "sync:status")
    end

    {:ok,
     assign(socket,
       [sync_in_progress: false, show_force: false, league_count: @league_count, sync_errors: []]
       |> Keyword.merge(Map.to_list(load_stats()))
     )}
  end

  @impl true
  def handle_info({:odds_updated, _payload}, socket) do
    # Intentionally skip full stats reload here — odds_updated fires once per league
    # (up to 12x per sync cycle). Stats are refreshed once on sync_complete instead.
    {:noreply, socket}
  end

  @impl true
  def handle_info({:sync_started, _}, socket) do
    {:noreply, assign(socket, sync_in_progress: true, sync_errors: [])}
  end

  @impl true
  def handle_info({:sync_complete, _}, socket) do
    {:noreply, assign(socket, [sync_in_progress: false] ++ Map.to_list(load_stats()))}
  end

  @impl true
  def handle_info({:sync_error, %{league: league, error: error}}, socket) do
    entry = "#{league}: #{error}"
    errors = [entry | socket.assigns.sync_errors] |> Enum.take(5)
    {:noreply, assign(socket, sync_errors: errors, sync_in_progress: false)}
  end

  @impl true
  def handle_event("trigger_sync", %{"force" => force}, socket) do
    BettingEngine.Sync.Poller.sync_now(force: force == "true")
    {:noreply, assign(socket, sync_in_progress: true)}
  end

  @impl true
  def handle_event("toggle_force", _, socket) do
    {:noreply, assign(socket, show_force: !socket.assigns.show_force)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="text-3xl font-bold tracking-tight">Dashboard</h1>
        <p class="mt-1 text-sm text-muted-foreground">Daten-Synchronisierung via The Odds API.</p>
      </div>

      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.stat_card title="Fußball" value={@football_total} sub={"#{@football_upcoming} anstehend"} icon="football" />
        <.stat_card title="Eishockey" value={@hockey_total} sub={"#{@hockey_upcoming} anstehend"} icon="hockey" />
        <.stat_card title="Quoten in DB" value={@odds_count} sub="Alle EU-Bookmaker, h2h" icon="chart" />
        <.stat_card title="Anstehende Spiele" value={@upcoming_count} sub="Alle Sportarten" icon="calendar" />
      </div>

      <.card>
        <.card_header class="pb-3">
          <.card_title>API Monitoring</.card_title>
          <p class="mt-1 text-xs text-muted-foreground">Verbrauch der The Odds API</p>
        </.card_header>
        <.card_content>
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium">The Odds API</span>
              <div class="flex items-baseline gap-1.5">
                <span class={"text-lg font-bold tabular-nums " <> api_text_color(@monthly_requests, 500)}>
                  <%= @monthly_requests %>
                </span>
                <span class="text-xs text-muted-foreground">/ 500</span>
                <span class="text-[10px] text-muted-foreground">(<%= 500 - @monthly_requests %> übrig)</span>
              </div>
            </div>
            <div class="h-2.5 w-full overflow-hidden rounded-full bg-secondary">
              <div
                class={"h-full rounded-full transition-all " <> api_bar_color(@monthly_requests, 500)}
                style={"width: #{min(100, round(@monthly_requests / 500 * 100))}%"}
              />
            </div>
            <p class="text-[10px] text-muted-foreground">500 Requests / Monat</p>
          </div>
        </.card_content>
      </.card>

      <div class="grid gap-6 lg:grid-cols-2">
        <div>
          <h2 class="mb-4 text-lg font-semibold">Data Sync</h2>
          <div class="space-y-4">
            <div class="rounded-lg border border-orange-500/40 bg-orange-500/10 p-4">
              <div class="flex items-start gap-3">
                <svg xmlns="http://www.w3.org/2000/svg" class="mt-0.5 h-5 w-5 shrink-0 text-orange-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
                <div>
                  <p class="text-sm font-semibold text-orange-500">
                    ACHTUNG: Ein Sync aller Ligen kostet <%= @league_count %> Requests!
                  </p>
                  <p class="mt-1 text-xs text-muted-foreground">
                    Bei 500 Requests/Monat darfst du diesen Button maximal 1× pro Tag drücken. Der 6-Stunden-Cache schützt vor versehentlichen Doppelklicks.
                  </p>
                </div>
              </div>
            </div>

            <.card>
              <.card_header>
                <.card_title class="text-base">Alle Ligen synchronisieren</.card_title>
                <p class="mt-1 text-xs text-muted-foreground"><%= @league_count %> Ligen · 1s Delay · 6h Cache-Schutz</p>
              </.card_header>
              <.card_content class="space-y-4">
                <.button variant="outline" class="w-full" phx-click="trigger_sync" phx-value-force="false" disabled={@sync_in_progress}>
                  <%= if @sync_in_progress do %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>
                    Synchronisiere <%= @league_count %> Ligen…
                  <% else %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/></svg>
                    Sync Alle Ligen (<%= @league_count %> Requests)
                  <% end %>
                </.button>

                <%= if @sync_errors != [] do %>
                  <div class="rounded-lg border border-destructive/50 bg-destructive/10 p-3 space-y-1">
                    <p class="text-xs font-semibold text-destructive">Sync-Fehler:</p>
                    <%= for err <- @sync_errors do %>
                      <p class="font-mono text-[11px] text-destructive break-all"><%= err %></p>
                    <% end %>
                  </div>
                <% end %>

                <div class="border-t pt-4">
                  <%= if not @show_force do %>
                    <button phx-click="toggle_force" class="text-xs text-muted-foreground transition-colors hover:text-destructive">
                      Force Sync anzeigen (umgeht 6h-Cache-Schutz)…
                    </button>
                  <% else %>
                    <div class="space-y-2 rounded-lg border border-destructive/30 bg-destructive/5 p-3">
                      <p class="text-xs font-medium text-destructive">Force Sync — umgeht den Cache-Schutz!</p>
                      <p class="text-xs text-muted-foreground">Verbraucht bis zu <%= @league_count %> deiner 500 monatlichen Requests.</p>
                      <.button variant="destructive" size="sm" phx-click="trigger_sync" phx-value-force="true" disabled={@sync_in_progress}>
                        Force Sync (<%= @league_count %> Requests, Cache ignorieren)
                      </.button>
                    </div>
                  <% end %>
                </div>
              </.card_content>
            </.card>
          </div>
        </div>

        <div>
          <h2 class="mb-4 text-lg font-semibold">Sync-Protokoll</h2>
          <.card>
            <.card_content class="pt-6">
              <%= if @recent_logs == [] do %>
                <p class="text-sm text-muted-foreground">Noch keine Sync-Einträge vorhanden.</p>
              <% else %>
                <div class="max-h-96 space-y-1 overflow-auto">
                  <%= for log <- @recent_logs do %>
                    <div class="flex items-center gap-3 rounded px-2 py-1.5 text-xs hover:bg-muted/50">
                      <span class="w-12 shrink-0 text-muted-foreground"><%= Calendar.strftime(log.synced_at, "%H:%M") %></span>
                      <.badge variant={if log.status == "success", do: "default", else: "destructive"} class="w-14 justify-center text-[10px]">
                        <%= if log.status == "success", do: "OK", else: "Fehler" %>
                      </.badge>
                      <span class="min-w-0 flex-1 truncate font-mono"><%= shorten_endpoint(log.endpoint) %></span>
                      <%= if log.record_count do %>
                        <span class="shrink-0 text-muted-foreground"><%= log.record_count %> Events</span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </.card_content>
          </.card>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :sub, :string, default: nil
  attr :icon, :string, default: nil

  defp stat_card(assigns) do
    ~H"""
    <.card>
      <.card_header class="flex flex-row items-center justify-between pb-2">
        <.card_title class="text-sm font-medium"><%= @title %></.card_title>
        <.stat_icon name={@icon} />
      </.card_header>
      <.card_content>
        <div class="text-2xl font-bold"><%= @value %></div>
        <%= if @sub do %><p class="text-xs text-muted-foreground"><%= @sub %></p><% end %>
      </.card_content>
    </.card>
    """
  end

  defp stat_icon(%{name: "football"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>
    """
  end

  defp stat_icon(%{name: "hockey"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 20a7 7 0 0 1 14 0"/><path d="M12 13V7"/><path d="m9 10 3-3 3 3"/></svg>
    """
  end

  defp stat_icon(%{name: "chart"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" x2="18" y1="20" y2="10"/><line x1="12" x2="12" y1="20" y2="4"/><line x1="6" x2="6" y1="20" y2="14"/></svg>
    """
  end

  defp stat_icon(%{name: "calendar"} = assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="4" rx="2" ry="2"/><line x1="16" x2="16" y1="2" y2="6"/><line x1="8" x2="8" y1="2" y2="6"/><line x1="3" x2="21" y1="10" y2="10"/></svg>
    """
  end

  defp stat_icon(assigns) do
    ~H"""
    <span />
    """
  end

  defp api_text_color(used, limit) do
    pct = used / limit * 100
    cond do
      pct > 80 -> "text-red-500"
      pct > 50 -> "text-yellow-500"
      true -> "text-green-500"
    end
  end

  defp api_bar_color(used, limit) do
    pct = used / limit * 100
    cond do
      pct > 80 -> "bg-red-500"
      pct > 50 -> "bg-yellow-500"
      true -> "bg-green-500"
    end
  end

  defp shorten_endpoint(endpoint) do
    case Regex.run(~r|/v4/sports/([^/]+)/|, endpoint) do
      [_, key] -> key
      _ -> String.slice(endpoint, 0, 40)
    end
  end

  defp load_stats do
    now = DateTime.utc_now()

    upcoming_count =
      from(f in Fixture, where: f.date > ^now, select: count()) |> Repo.one()

    odds_count = Repo.aggregate(Odd, :count)

    fixtures_by_sport =
      from(s in Sport,
        left_join: f in assoc(s, :fixtures),
        group_by: [s.id, s.name],
        select: %{
          name: s.name,
          count: count(f.id),
          upcoming: fragment("COALESCE(SUM(CASE WHEN ? > ? THEN 1 ELSE 0 END), 0)", f.date, ^now)
        }
      )
      |> Repo.all()

    football =
      Enum.find(fixtures_by_sport, %{count: 0, upcoming: 0}, fn s ->
        String.downcase(s.name) |> String.contains?("football")
      end)

    hockey =
      Enum.find(fixtures_by_sport, %{count: 0, upcoming: 0}, fn s ->
        n = String.downcase(s.name)
        String.contains?(n, "hockey") or String.contains?(n, "eishockey")
      end)

    recent_logs =
      from(l in ApiSyncLog, order_by: [desc: l.synced_at], limit: 20) |> Repo.all()

    %{
      upcoming_count: upcoming_count,
      odds_count: odds_count,
      fixtures_by_sport: fixtures_by_sport,
      football_total: football.count,
      football_upcoming: football.upcoming,
      hockey_total: hockey.count,
      hockey_upcoming: hockey.upcoming,
      monthly_requests: OddsClient.monthly_requests_used(),
      recent_logs: recent_logs
    }
  end
end
