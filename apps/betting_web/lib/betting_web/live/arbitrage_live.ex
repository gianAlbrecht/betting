defmodule BettingWeb.ArbitrageLive do
  use BettingWeb, :live_view

  alias BettingEngine.Analysis.Arbitrage
  alias BettingEngine.Repo
  alias BettingEngine.Schemas.SavedBet

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BettingEngine.PubSub, "sync:status")
    end

    opportunities = Arbitrage.find_opportunities()

    {:ok,
     assign(socket,
       opportunities: opportunities,
       count: length(opportunities),
       budgets: %{},
       saved: MapSet.new()
     )}
  end

  @impl true
  def handle_info({:sync_complete, _}, socket) do
    opportunities = Arbitrage.find_opportunities()
    {:noreply, assign(socket, opportunities: opportunities, count: length(opportunities))}
  end

  @impl true
  def handle_info({:sync_started, _}, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:sync_error, _}, socket), do: {:noreply, socket}

  @impl true
  def handle_event("update_budget", %{"fixture_id" => fid, "budget" => budget_str}, socket) do
    case Float.parse(budget_str) do
      {v, _} when v > 0 ->
        {:noreply, assign(socket, budgets: Map.put(socket.assigns.budgets, fid, v))}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_bet", params, socket) do
    fixture_id = String.to_integer(params["fixture_id"])
    arb = Enum.find(socket.assigns.opportunities, &(&1.fixture_id == fixture_id))

    if arb do
      budget = Map.get(socket.assigns.budgets, params["fixture_id"], 100.0)
      stakes = calculate_stakes(budget, arb.arb_margin, arb.outcomes)

      best_outcome =
        [arb.outcomes.home, arb.outcomes.draw, arb.outcomes.away]
        |> Enum.reject(&is_nil/1)
        |> Enum.max_by(& &1.best_odd)

      %SavedBet{}
      |> SavedBet.changeset(%{
        fixture_id: fixture_id,
        type: "Surebet",
        outcome_label: "Arb #{arb.home_team} vs #{arb.away_team}",
        bookmaker_name: best_outcome.bookmaker,
        odds: best_outcome.best_odd,
        stake: budget,
        potential_payout: stakes.payout
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
        <h1 class="text-3xl font-bold tracking-tight">Arbitrage / Surebet Finder</h1>
        <p class="mt-1 text-sm text-muted-foreground">
          Finde garantierte Gewinne durch Quoten-Differenzen zwischen Buchmachern — rein aus der lokalen Datenbank, ohne API-Calls.
        </p>
      </div>

      <div class="flex flex-wrap items-center gap-3 text-sm text-muted-foreground">
        <%= if @count > 0 do %>
          <.badge variant="success"><%= @count %> Surebet<%= if @count != 1, do: "s" %> gefunden</.badge>
          <span>·</span>
          <span>Bester Profit: <span class="font-bold text-green-500">+<%= hd(@opportunities).profit_percent %>%</span></span>
        <% else %>
          <span>Keine Surebets gefunden</span>
        <% end %>
      </div>

      <div class="flex items-start gap-2 rounded-lg border bg-muted/30 px-4 py-3 text-xs text-muted-foreground">
        <span class="mt-0.5 shrink-0 text-base">💡</span>
        <div class="space-y-1">
          <p>
            <span class="font-semibold text-foreground">Surebets</span> entstehen, wenn verschiedene Buchmacher so unterschiedliche Quoten anbieten, dass du mit den richtigen Einsätzen bei <span class="font-semibold text-foreground">jedem Spielausgang</span> Gewinn machst.
          </p>
          <p>Es werden ausschliesslich bereits synchronisierte Quoten aus der lokalen Datenbank ausgewertet — keine neuen API-Calls.</p>
        </div>
      </div>

      <%= if @opportunities == [] do %>
        <div class="rounded-xl border bg-card py-16 text-center text-muted-foreground">
          <p class="text-4xl">📊</p>
          <p class="mt-4 text-lg font-medium">Aktuell keine Arbitrage-Möglichkeiten</p>
          <p class="mt-1 text-sm">Synchronisiere mehr Ligen und Quoten über das Dashboard.</p>
        </div>
      <% else %>
        <div class="grid gap-4">
          <%= for arb <- @opportunities do %>
            <.arb_card arb={arb} budget={Map.get(@budgets, to_string(arb.fixture_id), 100.0)} saved={MapSet.member?(@saved, arb.fixture_id)} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :arb, :map, required: true
  attr :budget, :float, required: true
  attr :saved, :boolean, default: false

  defp arb_card(assigns) do
    assigns =
      assign(assigns, stakes: calculate_stakes(assigns.budget, assigns.arb.arb_margin, assigns.arb.outcomes))

    ~H"""
    <.card class="transition-shadow hover:shadow-md">
      <.card_header class="pb-3">
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0 flex-1 space-y-1">
            <div class="flex items-center gap-2">
              <.badge variant="outline" class="shrink-0 text-[10px]">
                <%= if @arb.league_country, do: "#{@arb.league_country} · " %><%= @arb.league_name %>
              </.badge>
            </div>
            <p class="text-lg font-semibold leading-tight">
              <%= @arb.home_team %> <span class="text-muted-foreground">vs</span> <%= @arb.away_team %>
            </p>
            <p class="text-xs text-muted-foreground">
              <%= Calendar.strftime(@arb.date, "%a, %d. %b · %H:%M") %>
            </p>
          </div>
          <.badge variant="success" class="shrink-0">Garantiert: +<%= @arb.profit_percent %>%</.badge>
        </div>
      </.card_header>

      <.card_content class="space-y-4">
        <div class="flex items-center gap-3">
          <label class="shrink-0 text-sm font-medium">Gesamt-Einsatz</label>
          <div class="relative max-w-[160px]">
            <.ui_input
              type="number"
              min="1"
              step="10"
              value={@budget}
              phx-change="update_budget"
              phx-value-fixture_id={@arb.fixture_id}
              name="budget"
              phx-debounce="300"
              class="pr-8 tabular-nums"
            />
            <span class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-muted-foreground">€</span>
          </div>
        </div>

        <.separator />

        <div class={"grid gap-3 " <> if(@arb.outcomes.draw, do: "grid-cols-3", else: "grid-cols-2")}>
          <.outcome_cell label="1" team={@arb.home_team} outcome={@arb.outcomes.home} stake={@stakes.home} />
          <%= if @arb.outcomes.draw do %>
            <.outcome_cell label="X" team="Unentschieden" outcome={@arb.outcomes.draw} stake={@stakes.draw} />
          <% end %>
          <.outcome_cell label="2" team={@arb.away_team} outcome={@arb.outcomes.away} stake={@stakes.away} />
        </div>

        <.separator />

        <div class="flex items-center justify-between rounded-lg border border-green-500/20 bg-green-500/5 px-4 py-3">
          <div class="space-y-0.5">
            <p class="text-xs text-muted-foreground">Garantierte Auszahlung (egal welches Ergebnis)</p>
            <p class="text-xl font-bold tabular-nums text-green-500"><%= :erlang.float_to_binary(@stakes.payout, decimals: 2) %> €</p>
          </div>
          <div class="text-right space-y-0.5">
            <p class="text-xs text-muted-foreground">Reingewinn</p>
            <p class="text-xl font-bold tabular-nums text-green-500">+<%= :erlang.float_to_binary(@stakes.profit, decimals: 2) %> €</p>
          </div>
        </div>

        <.button
          variant="outline"
          size="sm"
          class="w-full"
          disabled={@saved}
          phx-click="save_bet"
          phx-value-fixture_id={@arb.fixture_id}
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

  attr :label, :string, required: true
  attr :team, :string, required: true
  attr :outcome, :map, required: true
  attr :stake, :float, required: true

  defp outcome_cell(assigns) do
    ~H"""
    <div class="space-y-2 rounded-lg border bg-muted/20 p-3">
      <div class="text-center">
        <span class="text-2xl font-black tabular-nums"><%= @label %></span>
        <p class="mt-0.5 truncate text-xs text-muted-foreground"><%= @team %></p>
      </div>
      <.separator />
      <div class="text-center">
        <p class="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">Quote</p>
        <p class="text-xl font-bold tabular-nums text-primary"><%= :erlang.float_to_binary(@outcome.best_odd, decimals: 2) %></p>
      </div>
      <div class="text-center">
        <p class="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">Buchmacher</p>
        <p class="truncate text-xs font-medium"><%= @outcome.bookmaker %></p>
      </div>
      <.separator />
      <div class="text-center">
        <p class="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">Einsatz</p>
        <div class="relative mx-auto max-w-[120px]">
          <.ui_input readonly value={:erlang.float_to_binary(@stake, decimals: 2)} class="text-center font-bold tabular-nums pr-6" />
          <span class="pointer-events-none absolute right-2 top-1/2 -translate-y-1/2 text-xs text-muted-foreground">€</span>
        </div>
      </div>
    </div>
    """
  end

  defp calculate_stakes(budget, arb_margin, outcomes) do
    home_stake = budget * (1 / outcomes.home.best_odd / arb_margin)
    draw_stake = if outcomes.draw, do: budget * (1 / outcomes.draw.best_odd / arb_margin), else: 0.0
    away_stake = budget * (1 / outcomes.away.best_odd / arb_margin)
    payout = budget / arb_margin
    profit = payout - budget

    %{
      home: home_stake,
      draw: draw_stake,
      away: away_stake,
      payout: payout,
      profit: profit
    }
  end
end
