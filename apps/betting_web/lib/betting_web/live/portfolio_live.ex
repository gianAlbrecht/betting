defmodule BettingWeb.PortfolioLive do
  use BettingWeb, :live_view

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.SavedBet
  import Ecto.Query

  @finished_statuses ~w(FT AET PEN)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BettingEngine.PubSub, "results:updated")
    end

    data = load_portfolio()

    {:ok,
     assign(socket,
       bets: data.bets,
       stats: data.stats,
       settle_result: nil,
       expanded: MapSet.new()
     )}
  end

  @impl true
  def handle_info({:results_updated, _}, socket) do
    result = settle_finished_bets()
    data = load_portfolio()

    settle_result =
      if result.settled > 0, do: result, else: socket.assigns.settle_result

    {:noreply, assign(socket, bets: data.bets, stats: data.stats, settle_result: settle_result)}
  end

  @impl true
  def handle_event("toggle_details", %{"id" => id}, socket) do
    id_int = String.to_integer(id)
    expanded = socket.assigns.expanded

    expanded =
      if MapSet.member?(expanded, id_int),
        do: MapSet.delete(expanded, id_int),
        else: MapSet.put(expanded, id_int)

    {:noreply, assign(socket, expanded: expanded)}
  end

  @impl true
  def handle_event("delete_bet", %{"id" => id}, socket) do
    Repo.delete!(Repo.get!(SavedBet, String.to_integer(id)))
    data = load_portfolio()
    {:noreply, assign(socket, bets: data.bets, stats: data.stats)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-3xl font-bold tracking-tight">Bet Tracker & Portfolio</h1>
        <p class="mt-1 text-sm text-muted-foreground">Übersicht aller gespeicherten Wetten — Ergebnisse werden automatisch synchronisiert.</p>
      </div>

      <%!-- Stats row --%>
      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.card>
          <.card_header class="flex flex-row items-center justify-between pb-2">
            <.card_title class="text-sm font-medium">Total Wetten</.card_title>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          </.card_header>
          <.card_content>
            <div class="text-2xl font-bold"><%= @stats.total %></div>
            <p class="text-xs text-muted-foreground">
              <span class="text-blue-500"><%= @stats.open %> offen</span>
              · <span class="text-green-500"><%= @stats.won %> gewonnen</span>
              · <span class="text-red-400"><%= @stats.lost %> verloren</span>
            </p>
          </.card_content>
        </.card>

        <.card>
          <.card_header class="flex flex-row items-center justify-between pb-2">
            <.card_title class="text-sm font-medium">Eingesetzt</.card_title>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 17 13.5 8.5 8.5 13.5 2 7"/><polyline points="16 17 22 17 22 11"/></svg>
          </.card_header>
          <.card_content>
            <div class="text-2xl font-bold tabular-nums"><%= format_money(@stats.total_staked) %> €</div>
            <p class="text-xs text-muted-foreground">Gesamt über alle Wetten</p>
          </.card_content>
        </.card>

        <.card>
          <.card_header class="flex flex-row items-center justify-between pb-2">
            <.card_title class="text-sm font-medium">Auszahlungen</.card_title>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/></svg>
          </.card_header>
          <.card_content>
            <div class="text-2xl font-bold tabular-nums text-green-500"><%= format_money(@stats.total_returns) %> €</div>
            <p class="text-xs text-muted-foreground">Nur abgeschlossene (Won)</p>
          </.card_content>
        </.card>

        <.card>
          <.card_header class="flex flex-row items-center justify-between pb-2">
            <.card_title class="text-sm font-medium">ROI / Gewinn</.card_title>
            <svg xmlns="http://www.w3.org/2000/svg" class={"h-4 w-4 " <> roi_color(@stats.profit_loss)} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points={if(@stats.profit_loss >= 0, do: "22 7 13.5 15.5 8.5 10.5 2 17", else: "22 17 13.5 8.5 8.5 13.5 2 7")}/></svg>
          </.card_header>
          <.card_content>
            <div class={"text-2xl font-bold tabular-nums " <> roi_color(@stats.profit_loss)}>
              <%= if @stats.profit_loss >= 0, do: "+" %><%= format_money(@stats.profit_loss) %> €
            </div>
            <p class={"text-xs font-semibold " <> roi_color(@stats.profit_loss)}>
              ROI: <%= if @stats.roi >= 0, do: "+" %><%= Float.round(@stats.roi, 1) %>%
            </p>
          </.card_content>
        </.card>
      </div>

      <%!-- Auto-settle notification --%>
      <%= if @settle_result && @settle_result.settled > 0 do %>
        <div class="flex items-center gap-2 rounded-lg border border-green-500/30 bg-green-500/5 px-4 py-2 text-sm text-green-500">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
          <span>Auto-Settlement: <%= @settle_result.message %></span>
        </div>
      <% end %>

      <.separator />

      <%!-- Bet list --%>
      <%= if @bets == [] do %>
        <div class="rounded-xl border bg-card py-16 text-center text-muted-foreground">
          <p class="text-4xl">🎰</p>
          <p class="mt-4 text-lg font-medium">Noch keine Wetten gespeichert</p>
          <p class="mt-1 text-sm">Speichere Value Bets, Surebets oder Kombiwetten über die jeweiligen Analysen.</p>
        </div>
      <% else %>
        <div class="space-y-2">
          <%= for bet <- @bets do %>
            <.bet_row bet={bet} expanded={MapSet.member?(@expanded, bet.id)} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ─── Components ──────────────────────────────────────────

  attr :bet, :map, required: true
  attr :expanded, :boolean, default: false

  defp bet_row(assigns) do
    ~H"""
    <div class="overflow-hidden rounded-lg border bg-card">
      <%!-- Main compact row --%>
      <div class="flex items-center gap-3 px-4 py-3">
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-1.5">
            <span class="text-sm"><%= type_emoji(@bet.type) %></span>
            <.badge variant="outline" class="shrink-0 text-[10px]"><%= @bet.league_name %></.badge>
            <.badge class={"shrink-0 text-[10px] " <> status_badge_class(@bet.status)}>
              <%= @bet.status %>
            </.badge>
            <%= if match_live?(@bet) do %>
              <.badge class="shrink-0 animate-pulse text-[10px] border-orange-500/30 bg-orange-500/10 text-orange-500">LIVE</.badge>
            <% end %>
          </div>
          <p class="mt-1 text-sm font-semibold leading-tight">
            <%= @bet.home_team %> <span class="text-muted-foreground">vs</span> <%= @bet.away_team %>
          </p>
          <p class="text-xs text-muted-foreground">
            <%= Calendar.strftime(@bet.match_date, "%d. %b %Y · %H:%M") %>
            · <span class="font-medium"><%= @bet.outcome_label %></span>
            @ <%= @bet.bookmaker_name %>
          </p>
        </div>

        <div class="shrink-0 text-right">
          <p class="text-lg font-bold tabular-nums"><%= :erlang.float_to_binary(@bet.odds, decimals: 2) %></p>
          <p class="text-xs text-muted-foreground">
            <%= format_money(@bet.stake) %> € → <%= format_money(@bet.potential_payout) %> €
          </p>
        </div>

        <%!-- Expand / collapse toggle --%>
        <button
          phx-click="toggle_details"
          phx-value-id={@bet.id}
          class="shrink-0 rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          aria-label="Match-Details"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class={"h-4 w-4 transition-transform " <> if(@expanded, do: "rotate-180", else: "")}
            viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
          ><path d="m6 9 6 6 6-6"/></svg>
        </button>

        <.button
          variant="ghost"
          size="icon"
          class="h-8 w-8 shrink-0 text-muted-foreground hover:text-destructive"
          phx-click="delete_bet"
          phx-value-id={@bet.id}
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
        </.button>
      </div>

      <%!-- Live stats panel (expanded) --%>
      <%= if @expanded do %>
        <div class="border-t bg-muted/20 px-4 py-4">
          <p class="mb-3 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">Match Stats</p>

          <%= cond do %>
            <% @bet.home_score != nil -> %>
              <%!-- Result known --%>
              <div class="flex items-center justify-center gap-6 py-2">
                <div class="text-right">
                  <p class="text-sm font-semibold"><%= @bet.home_team %></p>
                </div>
                <div class="text-center">
                  <p class="text-3xl font-black tabular-nums">
                    <span class={if @bet.home_score > @bet.away_score, do: "text-green-500", else: ""}>
                      <%= @bet.home_score %>
                    </span>
                    <span class="mx-1 text-muted-foreground">–</span>
                    <span class={if @bet.away_score > @bet.home_score, do: "text-green-500", else: ""}>
                      <%= @bet.away_score %>
                    </span>
                  </p>
                  <.badge variant="outline" class="mt-1 text-[10px]">
                    <%= @bet.fixture_status_short || "FT" %>
                  </.badge>
                </div>
                <div class="text-left">
                  <p class="text-sm font-semibold"><%= @bet.away_team %></p>
                </div>
              </div>

              <div class="mt-3 flex items-center justify-center gap-2 rounded-lg border px-3 py-2 text-xs">
                <%= case @bet.status do %>
                  <% "Won" -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-green-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
                    <span class="font-semibold text-green-500">Gewonnen — Auszahlung: <%= format_money(@bet.potential_payout) %> €</span>
                  <% "Lost" -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-red-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
                    <span class="font-semibold text-red-400">Verloren — Einsatz: <%= format_money(@bet.stake) %> €</span>
                  <% _ -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/></svg>
                    <span class="text-muted-foreground">Ergebnis ausstehend</span>
                <% end %>
              </div>

            <% match_started?(@bet) -> %>
              <%!-- Past kickoff but no score yet --%>
              <div class="flex items-center justify-center gap-6 py-2">
                <p class="text-sm font-semibold"><%= @bet.home_team %></p>
                <div class="text-center">
                  <p class="text-3xl font-black tabular-nums text-muted-foreground">? – ?</p>
                  <p class="mt-1 text-[10px] text-muted-foreground">Warte auf Ergebnis…</p>
                </div>
                <p class="text-sm font-semibold"><%= @bet.away_team %></p>
              </div>
              <p class="mt-2 text-center text-[10px] text-muted-foreground">Ergebnis wird automatisch per API-Sports synchronisiert.</p>

            <% true -> %>
              <%!-- Upcoming --%>
              <div class="flex items-center justify-center gap-6 py-2">
                <p class="text-sm font-semibold"><%= @bet.home_team %></p>
                <div class="text-center">
                  <p class="text-lg font-bold text-muted-foreground">vs</p>
                  <p class="text-[10px] text-muted-foreground">
                    <%= Calendar.strftime(@bet.match_date, "%a, %d. %b · %H:%M") %>
                  </p>
                </div>
                <p class="text-sm font-semibold"><%= @bet.away_team %></p>
              </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ─── Helpers ─────────────────────────────────────────────

  defp type_emoji("Value"), do: "💎"
  defp type_emoji("Surebet"), do: "⚖️"
  defp type_emoji("Parlay"), do: "🔗"
  defp type_emoji(_), do: "🎯"

  defp status_badge_class("Won"), do: "border-green-500/30 bg-green-500/10 text-green-500"
  defp status_badge_class("Lost"), do: "border-red-400/30 bg-red-400/10 text-red-400"
  defp status_badge_class(_), do: "border-blue-500/30 bg-blue-500/10 text-blue-500"

  defp roi_color(val) when val >= 0, do: "text-green-500"
  defp roi_color(_), do: "text-red-400"

  defp match_started?(%{match_date: date}),
    do: DateTime.compare(date, DateTime.utc_now()) == :lt

  defp match_live?(%{fixture_status_short: s}) when s in ~w(1H HT 2H ET BT), do: true
  defp match_live?(_), do: false

  defp format_money(val) when is_float(val), do: :erlang.float_to_binary(val, decimals: 2)
  defp format_money(val), do: to_string(val)

  # ─── Data loading ─────────────────────────────────────────

  defp load_portfolio do
    bets =
      from(b in SavedBet,
        order_by: [desc: b.inserted_at],
        preload: [fixture: [:home_team, :away_team, :league, :sport]]
      )
      |> Repo.all()

    bet_views =
      Enum.map(bets, fn b ->
        %{
          id: b.id,
          fixture_id: b.fixture_id,
          type: b.type,
          outcome_label: b.outcome_label,
          bookmaker_name: b.bookmaker_name,
          odds: b.odds,
          stake: b.stake,
          potential_payout: b.potential_payout,
          status: b.status,
          home_team: b.fixture.home_team.name,
          away_team: b.fixture.away_team.name,
          league_name: b.fixture.league.name,
          match_date: b.fixture.date,
          sport_slug: b.fixture.sport.slug,
          # Match result fields (populated by ResultsSync via API-Sports)
          home_score: b.fixture.home_score,
          away_score: b.fixture.away_score,
          fixture_status: b.fixture.status,
          fixture_status_short: b.fixture.status_short,
          elapsed: b.fixture.elapsed
        }
      end)

    total_staked = Enum.sum(Enum.map(bets, & &1.stake))
    total_returns = bets |> Enum.filter(&(&1.status == "Won")) |> Enum.sum_by(& &1.potential_payout)
    settled_stake = bets |> Enum.filter(&(&1.status != "Open")) |> Enum.sum_by(& &1.stake)
    profit_loss = total_returns - settled_stake
    roi = if settled_stake > 0, do: profit_loss / settled_stake * 100, else: 0.0

    %{
      bets: bet_views,
      stats: %{
        total: length(bets),
        open: Enum.count(bets, &(&1.status == "Open")),
        won: Enum.count(bets, &(&1.status == "Won")),
        lost: Enum.count(bets, &(&1.status == "Lost")),
        total_staked: total_staked,
        total_returns: total_returns,
        profit_loss: profit_loss,
        roi: roi
      }
    }
  end

  # ─── Settlement ───────────────────────────────────────────

  defp settle_finished_bets do
    now = DateTime.utc_now()

    open_bets =
      from(b in SavedBet,
        where: b.status == "Open",
        preload: [fixture: [:home_team, :away_team]]
      )
      |> Repo.all()

    {settled, won, lost} =
      Enum.reduce(open_bets, {0, 0, 0}, fn bet, {s, w, l} ->
        fix = bet.fixture

        with true <- DateTime.compare(fix.date, now) == :lt,
             true <- fix.status_short in @finished_statuses or fix.home_score != nil,
             new_status when not is_nil(new_status) <- determine_status(bet, fix) do
          bet |> SavedBet.changeset(%{status: new_status}) |> Repo.update!()
          {s + 1, (if new_status == "Won", do: w + 1, else: w),
           (if new_status == "Lost", do: l + 1, else: l)}
        else
          _ -> {s, w, l}
        end
      end)

    %{
      settled: settled,
      won: won,
      lost: lost,
      message: "#{settled} Wetten: #{won} gewonnen, #{lost} verloren."
    }
  end

  defp determine_status(%{type: "Surebet"}, _fix), do: "Won"

  defp determine_status(bet, fix) do
    if fix.home_score == nil or fix.away_score == nil do
      nil
    else
      home_won = fix.home_score > fix.away_score
      away_won = fix.away_score > fix.home_score
      is_draw = fix.home_score == fix.away_score
      label = String.downcase(bet.outcome_label)
      home_name = String.downcase(fix.home_team.name)
      away_name = String.downcase(fix.away_team.name)

      cond do
        String.contains?(label, "unentschieden") or label in ["draw", "x"] ->
          if is_draw, do: "Won", else: "Lost"

        String.contains?(label, home_name) or String.contains?(home_name, label) ->
          if home_won, do: "Won", else: "Lost"

        String.contains?(label, away_name) or String.contains?(away_name, label) ->
          if away_won, do: "Won", else: "Lost"

        true ->
          nil
      end
    end
  end
end
