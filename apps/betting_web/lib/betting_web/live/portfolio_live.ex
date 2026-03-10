defmodule BettingWeb.PortfolioLive do
  use BettingWeb, :live_view

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.SavedBet
  import Ecto.Query

  @finished_statuses ~w(FT AET PEN AOT AP Match\ Finished Game\ Finished)

  @impl true
  def mount(_params, _session, socket) do
    data = load_portfolio()
    {:ok, assign(socket, bets: data.bets, stats: data.stats, settle_result: nil)}
  end

  @impl true
  def handle_event("update_status", %{"_id" => id, "status" => status}, socket) do
    bet = Repo.get!(SavedBet, String.to_integer(id))
    bet |> SavedBet.changeset(%{status: status}) |> Repo.update!()
    data = load_portfolio()
    {:noreply, assign(socket, bets: data.bets, stats: data.stats)}
  end

  @impl true
  def handle_event("delete_bet", %{"id" => id}, socket) do
    Repo.delete!(Repo.get!(SavedBet, String.to_integer(id)))
    data = load_portfolio()
    {:noreply, assign(socket, bets: data.bets, stats: data.stats)}
  end

  @impl true
  def handle_event("settle_bets", _, socket) do
    result = settle_finished_bets()
    data = load_portfolio()
    {:noreply, assign(socket, bets: data.bets, stats: data.stats, settle_result: result)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-3xl font-bold tracking-tight">Bet Tracker & Portfolio</h1>
        <p class="mt-1 text-sm text-muted-foreground">Übersicht aller gespeicherten Wetten mit ROI-Berechnung.</p>
      </div>

      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.card>
          <.card_header class="flex flex-row items-center justify-between pb-2">
            <.card_title class="text-sm font-medium">Total Wetten</.card_title>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          </.card_header>
          <.card_content>
            <div class="text-2xl font-bold"><%= @stats.total %></div>
            <p class="text-xs text-muted-foreground"><%= @stats.open %> offen · <%= @stats.won %> won · <%= @stats.lost %> lost</p>
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
            <svg xmlns="http://www.w3.org/2000/svg" class={"h-4 w-4 " <> if(@stats.profit_loss >= 0, do: "text-green-500", else: "text-red-400")} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points={if(@stats.profit_loss >= 0, do: "22 7 13.5 15.5 8.5 10.5 2 17", else: "22 17 13.5 8.5 8.5 13.5 2 7")}/></svg>
          </.card_header>
          <.card_content>
            <div class={"text-2xl font-bold tabular-nums " <> if(@stats.profit_loss >= 0, do: "text-green-500", else: "text-red-400")}>
              <%= if @stats.profit_loss >= 0, do: "+" %><%= format_money(@stats.profit_loss) %> €
            </div>
            <p class={"text-xs font-semibold " <> if(@stats.profit_loss >= 0, do: "text-green-500", else: "text-red-400")}>
              ROI: <%= if @stats.roi >= 0, do: "+" %><%= Float.round(@stats.roi, 1) %>%
            </p>
          </.card_content>
        </.card>
      </div>

      <div class="flex flex-wrap items-center gap-3">
        <.button variant="outline" size="sm" phx-click="settle_bets" disabled={@stats.open == 0}>
          <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
          Auto-Settlement (<%= @stats.open %> offen)
        </.button>
        <%= if @settle_result do %>
          <.badge variant={if @settle_result.settled > 0, do: "success", else: "outline"}>
            <%= @settle_result.message %>
          </.badge>
        <% end %>
      </div>

      <.separator />

      <%= if @bets == [] do %>
        <div class="rounded-xl border bg-card py-16 text-center text-muted-foreground">
          <p class="text-4xl">🎰</p>
          <p class="mt-4 text-lg font-medium">Noch keine Wetten gespeichert</p>
          <p class="mt-1 text-sm">Speichere Value Bets, Surebets oder Kombiwetten über die jeweiligen Analysen.</p>
        </div>
      <% else %>
        <div class="space-y-2">
          <%= for bet <- @bets do %>
            <.bet_row bet={bet} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :bet, :map, required: true

  defp bet_row(assigns) do
    ~H"""
    <div class="flex items-center gap-4 rounded-lg border bg-card px-4 py-3">
      <div class="min-w-0 flex-1">
        <div class="flex items-center gap-2">
          <span class="text-sm"><%= type_emoji(@bet.type) %></span>
          <.badge variant="outline" class="shrink-0 text-[10px]"><%= @bet.league_name %></.badge>
          <.badge class={"shrink-0 text-[10px] " <> status_badge_class(@bet.status)}>
            <%= @bet.status %>
          </.badge>
        </div>
        <p class="mt-1 text-sm font-semibold"><%= @bet.home_team %> vs <%= @bet.away_team %></p>
        <p class="text-xs text-muted-foreground">
          <%= Calendar.strftime(@bet.match_date, "%d. %b %Y") %> · <%= @bet.outcome_label %> @ <%= @bet.bookmaker_name %>
        </p>
      </div>

      <div class="shrink-0 text-right">
        <p class="text-lg font-bold tabular-nums"><%= :erlang.float_to_binary(@bet.odds, decimals: 2) %></p>
        <p class="text-xs text-muted-foreground">
          <%= format_money(@bet.stake) %> € → <%= format_money(@bet.potential_payout) %> €
        </p>
      </div>

      <form phx-change="update_status" class="shrink-0">
        <input type="hidden" name="_id" value={@bet.id} />
        <select
          name="status"
          class="h-8 w-[100px] rounded-md border border-input bg-background px-2 text-xs outline-none focus:border-ring"
        >
          <option value="Open" selected={@bet.status == "Open"}>Open</option>
          <option value="Won" selected={@bet.status == "Won"}>Won</option>
          <option value="Lost" selected={@bet.status == "Lost"}>Lost</option>
        </select>
      </form>

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
    """
  end

  defp type_emoji("Value"), do: "💎"
  defp type_emoji("Surebet"), do: "⚖️"
  defp type_emoji("Parlay"), do: "🔗"
  defp type_emoji(_), do: "🎯"

  defp status_badge_class("Won"), do: "border-green-500/30 bg-green-500/10 text-green-500"
  defp status_badge_class("Lost"), do: "border-red-400/30 bg-red-400/10 text-red-400"
  defp status_badge_class(_), do: "border-blue-500/30 bg-blue-500/10 text-blue-500"

  defp format_money(val) when is_float(val), do: :erlang.float_to_binary(val, decimals: 2)
  defp format_money(val), do: to_string(val)

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
          sport_slug: b.fixture.sport.slug
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

        if DateTime.compare(fix.date, now) != :lt do
          {s, w, l}
        else
          is_finished =
            fix.status_short in @finished_statuses or
              fix.status in @finished_statuses or
              (fix.home_score != nil and fix.away_score != nil)

          if not is_finished do
            {s, w, l}
          else
            new_status = determine_status(bet, fix)

            if new_status do
              bet |> SavedBet.changeset(%{status: new_status}) |> Repo.update!()
              new_won = if new_status == "Won", do: w + 1, else: w
              new_lost = if new_status == "Lost", do: l + 1, else: l
              {s + 1, new_won, new_lost}
            else
              {s, w, l}
            end
          end
        end
      end)

    msg =
      if settled == 0,
        do: "Keine abzuschliessenden Wetten gefunden.",
        else: "#{settled} Wetten: #{won} gewonnen, #{lost} verloren."

    %{settled: settled, won: won, lost: lost, message: msg}
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
        String.contains?(label, "unentschieden") or label == "draw" or label == "x" ->
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
