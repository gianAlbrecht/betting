defmodule BettingWeb.ValueBetsLive do
  use BettingWeb, :live_view

  alias BettingEngine.Analysis.ValueBets
  alias BettingEngine.Repo
  alias BettingEngine.Schemas.SavedBet

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BettingEngine.PubSub, "sync:status")
    end

    fixtures = ValueBets.find_value_bets() |> sorted(true)

    {:ok,
     assign(socket,
       fixtures: fixtures,
       total_value_bets: count_value_bets(fixtures),
       saved: MapSet.new(),
       sort_desc: true,
       collapsed_leagues: MapSet.new()
     )}
  end

  @impl true
  def handle_info({:sync_complete, _}, socket) do
    fixtures = ValueBets.find_value_bets() |> sorted(socket.assigns.sort_desc)
    {:noreply, assign(socket, fixtures: fixtures, total_value_bets: count_value_bets(fixtures))}
  end

  @impl true
  def handle_info({:sync_started, _}, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:sync_error, _}, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_league", %{"league" => league}, socket) do
    collapsed =
      if MapSet.member?(socket.assigns.collapsed_leagues, league) do
        MapSet.delete(socket.assigns.collapsed_leagues, league)
      else
        MapSet.put(socket.assigns.collapsed_leagues, league)
      end

    {:noreply, assign(socket, collapsed_leagues: collapsed)}
  end

  @impl true
  def handle_event("toggle_sort", _, socket) do
    sort_desc = !socket.assigns.sort_desc
    fixtures = sorted(socket.assigns.fixtures, sort_desc)
    {:noreply, assign(socket, sort_desc: sort_desc, fixtures: fixtures)}
  end

  @impl true
  def handle_event("save_bet", params, socket) do
    fixture_id = String.to_integer(params["fixture_id"])
    fixture = Enum.find(socket.assigns.fixtures, &(&1.fixture_id == fixture_id))

    if fixture && fixture.value_outcomes != [] do
      best = Enum.max_by(fixture.value_outcomes, & &1.value)

      %SavedBet{}
      |> SavedBet.changeset(%{
        fixture_id: fixture_id,
        type: "Value",
        outcome_label: best.label,
        bookmaker_name: best.bookmaker,
        odds: best.odd,
        stake: 10.0,
        potential_payout: 10.0 * best.odd
      })
      |> Repo.insert()

      {:noreply, assign(socket, saved: MapSet.put(socket.assigns.saved, fixture_id))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-3xl font-bold tracking-tight">Value Bet Analyzer</h1>
        <p class="mt-1 text-sm text-muted-foreground">
          Vergleiche Bookmaker-Quoten mit dem de-viggierten Marktkonsens, um Value Bets zu identifizieren.
        </p>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap items-center gap-3 text-sm text-muted-foreground">
          <span><span class="font-semibold text-foreground"><%= length(@fixtures) %></span> Spiele</span>
          <span>·</span>
          <span><span class="font-semibold text-foreground"><%= @total_value_bets %></span> Value Bet Opportunities</span>
          <%= if @total_value_bets > 0 do %>
            <span>·</span>
            <.badge variant="success"><%= @total_value_bets %> Value Bets gefunden</.badge>
          <% end %>
        </div>

        <%= if length(@fixtures) > 1 do %>
          <button
            phx-click="toggle_sort"
            class="flex items-center gap-1.5 rounded-md border px-3 py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:bg-muted"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <%= if @sort_desc do %>
                <path d="M3 4h13"/><path d="M3 8h9"/><path d="M3 12h5"/><path d="m15 8 3 3 3-3"/><path d="M18 11V21"/>
              <% else %>
                <path d="M3 4h13"/><path d="M3 8h9"/><path d="M3 12h5"/><path d="m15 16 3-3 3 3"/><path d="M18 13V3"/>
              <% end %>
            </svg>
            Value %: <%= if @sort_desc, do: "Höchster zuerst", else: "Niedrigster zuerst" %>
          </button>
        <% end %>
      </div>

      <div class="flex items-center gap-2 rounded-lg border border-orange-500/30 bg-orange-500/5 px-3 py-2 text-xs text-muted-foreground">
        <span class="font-semibold text-orange-500">Hinweis:</span>
        Berechnung basiert auf de-viggierten Quoten-Konsens (kein API-Sports). Edge-Schwelle: 5%.
      </div>

      <%= if @fixtures == [] do %>
        <div class="rounded-xl border bg-card py-16 text-center text-muted-foreground">
          <p class="text-lg font-medium">Keine Value Bets gefunden</p>
          <p class="mt-1 text-sm">Synchronisiere zuerst Daten über das Dashboard.</p>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for {league, matches} <- group_by_league(@fixtures) do %>
            <% collapsed = MapSet.member?(@collapsed_leagues, league) %>
            <div class="rounded-xl border bg-card overflow-hidden">
              <button
                phx-click="toggle_league"
                phx-value-league={league}
                class="flex w-full items-center justify-between gap-2 px-4 py-3 text-left transition-colors hover:bg-muted/40"
              >
                <div class="flex items-center gap-2">
                  <span><%= sport_emoji(hd(matches).sport_slug) %></span>
                  <span class="text-sm font-semibold"><%= league %></span>
                  <span class="text-xs text-muted-foreground">(<%= length(matches) %>)</span>
                </div>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class={"h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-200 #{if collapsed, do: "-rotate-90", else: ""}"}
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="m6 9 6 6 6-6" />
                </svg>
              </button>
              <%= unless collapsed do %>
                <div class="grid gap-3 p-3 sm:grid-cols-2 lg:grid-cols-3">
                  <%= for fixture <- matches do %>
                    <.fixture_card fixture={fixture} saved={MapSet.member?(@saved, fixture.fixture_id)} />
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :fixture, :map, required: true
  attr :saved, :boolean, default: false

  defp fixture_card(assigns) do
    ~H"""
    <.card class="transition-shadow hover:shadow-md">
      <.card_content class="p-4">
        <div class="mb-3 flex items-start justify-between gap-2">
          <div class="min-w-0 flex-1">
            <.badge variant="outline" class="text-[10px]"><%= @fixture.league_name %></.badge>
            <p class="mt-1 font-semibold leading-tight">
              <%= @fixture.home_team %> vs <%= @fixture.away_team %>
            </p>
          </div>
          <div class="shrink-0 text-right text-xs text-muted-foreground">
            <p><%= Calendar.strftime(@fixture.date, "%a, %d. %b") %></p>
            <p class="font-medium"><%= Calendar.strftime(@fixture.date, "%H:%M") %></p>
          </div>
        </div>

        <div class="rounded-lg border bg-muted/20">
          <div class="grid grid-cols-4 gap-1 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
            <span>Tipp</span>
            <span class="text-right">Quote</span>
            <span class="text-right">Echt %</span>
            <span class="text-right">Value</span>
          </div>
          <.separator />
          <%= for outcome <- @fixture.value_outcomes do %>
            <div class="grid grid-cols-4 gap-1 bg-green-500/5 px-3 py-2 text-sm">
              <span class="truncate text-xs font-medium"><%= outcome.label %></span>
              <div class="text-right">
                <span class="font-bold tabular-nums"><%= outcome.odd %></span>
                <p class="text-[10px] text-muted-foreground">(<%= outcome.implied_probability %>%)</p>
              </div>
              <span class="text-right font-semibold tabular-nums"><%= outcome.true_probability %>%</span>
              <div class="flex items-center justify-end gap-1">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 text-green-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/></svg>
                <span class="font-bold tabular-nums text-green-500">+<%= outcome.value %>%</span>
              </div>
            </div>
          <% end %>
        </div>

        <div class="mt-3 flex items-center justify-center gap-2 rounded-lg border border-green-500/30 bg-green-500/10 p-2.5">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-green-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
          <span class="text-sm font-bold text-green-500">
            VALUE: <%= (Enum.max_by(@fixture.value_outcomes, & &1.value)).label %> +<%= (Enum.max_by(@fixture.value_outcomes, & &1.value)).value %>%
          </span>
        </div>

        <.button
          variant="outline"
          size="sm"
          class="mt-3 w-full"
          disabled={@saved}
          phx-click="save_bet"
          phx-value-fixture_id={@fixture.fixture_id}
        >
          <%= if @saved do %>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5 text-green-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
            Gespeichert
          <% else %>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"/></svg>
            Wette speichern
          <% end %>
        </.button>
      </.card_content>
    </.card>
    """
  end

  defp count_value_bets(fixtures) do
    Enum.sum(Enum.map(fixtures, &length(&1.value_outcomes)))
  end

  defp group_by_league(fixtures) do
    fixtures
    |> Enum.group_by(& &1.league_name)
    |> Enum.to_list()
  end

  defp sport_emoji("icehockey"), do: "🏒"
  defp sport_emoji(_), do: "⚽"

  defp sorted(fixtures, true) do
    Enum.sort_by(fixtures, &max_value/1, :desc)
  end

  defp sorted(fixtures, false) do
    Enum.sort_by(fixtures, &max_value/1, :asc)
  end

  defp max_value(%{value_outcomes: []}), do: 0.0

  defp max_value(%{value_outcomes: outcomes}) do
    outcomes |> Enum.map(& &1.value) |> Enum.max()
  end
end
