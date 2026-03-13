defmodule BettingWeb.ParlayLive do
  use BettingWeb, :live_view

  alias BettingEngine.Analysis.Parlay
  alias BettingEngine.Repo
  alias BettingEngine.Schemas.{SavedBet, Fixture}
  import Ecto.Query

  @default_params %{
    "legs" => "3",
    "min_total_odds" => "3.0",
    "max_total_odds" => "15.0",
    "max_single_odd" => "3.0"
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BettingEngine.PubSub, "odds:updated")
    end

    match_count = upcoming_match_count()

    {:ok,
     assign(socket,
       parlays: [],
       loading: false,
       params: @default_params,
       match_count: match_count,
       saved: MapSet.new()
     )}
  end

  @impl true
  def handle_event("generate", params, socket) do
    parsed = parse_params(params)
    lv = self()

    # Parlay generation can evaluate up to 10,000 combinations. Running it in a
    # supervised task keeps the LiveView process responsive (no blocked render)
    # and shows a loading spinner while the work happens in the background.
    Task.Supervisor.start_child(BettingEngine.TaskSupervisor, fn ->
      parlays = Parlay.generate(parsed)
      send(lv, {:parlays_ready, parlays})
    end)

    {:noreply, assign(socket, loading: true, params: params)}
  end

  @impl true
  def handle_event("save_parlay", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    parlay = Enum.at(socket.assigns.parlays, idx)

    if parlay && parlay.legs != [] do
      first_leg = hd(parlay.legs)
      legs_label =
        parlay.legs
        |> Enum.map(fn l -> "#{pick_label(l.pick)} #{l.home_team} vs #{l.away_team}" end)
        |> Enum.join(" | ")

      bookmakers =
        parlay.legs
        |> Enum.map(& &1.bookmaker)
        |> Enum.uniq()
        |> Enum.join(", ")

      %SavedBet{}
      |> SavedBet.changeset(%{
        fixture_id: first_leg.fixture_id,
        type: "Parlay",
        outcome_label: legs_label,
        bookmaker_name: bookmakers,
        odds: parlay.combined_odd,
        stake: 10.0,
        potential_payout: Float.round(parlay.combined_odd * 10.0, 2)
      })
      |> Repo.insert()

      {:noreply, assign(socket, saved: MapSet.put(socket.assigns.saved, idx))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:parlays_ready, parlays}, socket) do
    {:noreply, assign(socket, parlays: parlays, loading: false)}
  end

  @impl true
  def handle_info({:odds_updated, _}, socket) do
    {:noreply, assign(socket, parlays: [], match_count: upcoming_match_count())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-3xl font-bold tracking-tight">Parlay Generator</h1>
        <p class="mt-1 text-sm text-muted-foreground">
          Definiere deine Ziel-Parameter und finde die mathematisch sichersten Kombiwetten aus allen verfügbaren Spielen.
        </p>
      </div>

      <div class="grid gap-6 lg:grid-cols-[320px_1fr]">
        <%!-- Form --%>
        <.card>
          <.card_content class="space-y-5 p-5">
            <form phx-submit="generate">
              <div class="space-y-5">
                <div>
                  <p class="mb-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Ziel-Gesamtquote</p>
                  <div class="grid grid-cols-2 gap-3">
                    <div>
                      <label class="text-xs text-muted-foreground">Min</label>
                      <.ui_input type="number" name="min_total_odds" value={@params["min_total_odds"]} min="1.5" step="0.5" class="mt-1 tabular-nums" />
                    </div>
                    <div>
                      <label class="text-xs text-muted-foreground">Max</label>
                      <.ui_input type="number" name="max_total_odds" value={@params["max_total_odds"]} min="2.0" step="0.5" class="mt-1 tabular-nums" />
                    </div>
                  </div>
                </div>

                <.separator />

                <div>
                  <p class="mb-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Anzahl Spiele (Legs)</p>
                  <div class="grid grid-cols-4 gap-2">
                    <%= for n <- [2, 3, 4, 5] do %>
                      <button
                        type="button"
                        phx-click="generate"
                        phx-value-legs={n}
                        phx-value-min_total_odds={@params["min_total_odds"]}
                        phx-value-max_total_odds={@params["max_total_odds"]}
                        phx-value-max_single_odd={@params["max_single_odd"]}
                        class={"rounded-lg border py-2 text-sm font-semibold transition-all " <> if(to_string(@params["legs"]) == to_string(n), do: "border-primary bg-primary text-primary-foreground", else: "border-border bg-card hover:border-primary/50 hover:bg-primary/5")}
                      >
                        <%= n %>er
                      </button>
                    <% end %>
                  </div>
                </div>

                <.separator />

                <div>
                  <div class="mb-2 flex items-baseline justify-between">
                    <p class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Max. Einzelquote</p>
                    <span class="text-lg font-bold tabular-nums"><%= @params["max_single_odd"] %></span>
                  </div>
                  <input
                    type="range"
                    name="max_single_odd"
                    min="1.2"
                    max="5.0"
                    step="0.1"
                    value={@params["max_single_odd"]}
                    class="w-full cursor-pointer accent-primary"
                  />
                  <div class="mt-1 flex justify-between text-[10px] text-muted-foreground">
                    <span>1.2 (sicher)</span>
                    <span>5.0 (riskant)</span>
                  </div>
                </div>

                <.separator />

                <.button type="submit" class="w-full" disabled={@loading || @match_count == 0}>
                  <%= if @loading do %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>
                    Berechne Kombinationen…
                  <% else %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/></svg>
                    Parlays generieren
                  <% end %>
                </.button>

                <p class="text-center text-xs text-muted-foreground"><%= @match_count %> Spiele im Pool</p>
              </div>
            </form>
          </.card_content>
        </.card>

        <%!-- Results --%>
        <div>
          <%= if @parlays == [] and not @loading do %>
            <div class="rounded-xl border bg-card py-16 text-center text-muted-foreground">
              <p class="text-4xl">🎯</p>
              <p class="mt-4 text-lg font-medium">Parameter konfigurieren und Parlays generieren</p>
              <p class="mt-1 text-sm">Bis zu 10 Kombinationen werden angezeigt.</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <%= for {parlay, idx} <- Enum.with_index(@parlays) do %>
                <.parlay_card parlay={parlay} rank={idx + 1} saved={MapSet.member?(@saved, idx)} idx={idx} />
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :parlay, :map, required: true
  attr :rank, :integer, required: true
  attr :idx, :integer, required: true
  attr :saved, :boolean, default: false

  defp parlay_card(assigns) do
    ~H"""
    <.card class="transition-shadow hover:shadow-md">
      <.card_content class="p-4">
        <div class="mb-3 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <%= if @rank <= 3 do %>
              <span class={"text-sm " <> trophy_color(@rank)}>🏆</span>
            <% end %>
            <span class="text-sm font-semibold text-muted-foreground">#<%= @rank %></span>
          </div>
          <div class="flex items-center gap-2">
            <.badge variant="outline" class={risk_badge_class(@parlay.risk_level)}>
              <%= risk_label(@parlay.risk_level) %>
            </.badge>
            <span class="text-lg font-bold tabular-nums"><%= @parlay.combined_odd %></span>
          </div>
        </div>

        <.separator class="mb-3" />

        <div class="space-y-2">
          <%= for leg <- @parlay.legs do %>
            <div class="flex items-center gap-2 rounded-lg border bg-muted/30 px-3 py-2">
              <.badge variant="secondary" class="shrink-0 text-[10px]"><%= pick_label(leg.pick) %></.badge>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-medium"><%= leg.home_team %> vs <%= leg.away_team %></p>
                <p class="text-[10px] text-muted-foreground">
                  <%= leg.league_name %> · <%= Calendar.strftime(leg.date, "%a, %d. %b") %> · via <%= leg.bookmaker %>
                </p>
              </div>
              <div class="shrink-0 text-right">
                <p class="text-sm font-bold tabular-nums"><%= :erlang.float_to_binary(leg.odd, decimals: 2) %></p>
                <p class="truncate text-[10px] text-muted-foreground"><%= leg.pick %></p>
              </div>
            </div>
          <% end %>
        </div>

        <div class="mt-3 flex items-center justify-between text-xs text-muted-foreground">
          <span>Wahrscheinlichkeit: <span class={"font-semibold " <> risk_text_color(@parlay.risk_level)}><%= @parlay.implied_probability %>%</span></span>
          <span>Gewinn bei 10€: <span class="font-semibold text-foreground"><%= :erlang.float_to_binary(Float.round(@parlay.combined_odd * 10, 2), decimals: 2) %>€</span></span>
        </div>

        <.button
          variant="outline"
          size="sm"
          class="mt-3 w-full"
          disabled={@saved}
          phx-click="save_parlay"
          phx-value-index={@idx}
        >
          <%= if @saved do %>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5 text-green-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
            Gespeichert
          <% else %>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"/></svg>
            Kombiwette speichern
          <% end %>
        </.button>
      </.card_content>
    </.card>
    """
  end

  defp pick_label("Draw"), do: "X"
  defp pick_label(team_name) when is_binary(team_name) do
    # Picks are stored as team names (the raw label from The Odds API). There is
    # no separate "1" / "2" label — the team name IS the pick label for h2h bets.
    team_name
  end

  defp trophy_color(1), do: "text-yellow-500"
  defp trophy_color(2), do: "text-gray-400"
  defp trophy_color(3), do: "text-amber-700"
  defp trophy_color(_), do: ""

  defp risk_label("low"), do: "Geringes Risiko"
  defp risk_label("moderate"), do: "Moderates Risiko"
  defp risk_label("high"), do: "Hohes Risiko"
  defp risk_label(_), do: "Extremes Risiko"

  defp risk_badge_class("low"),
    do: "text-green-500 bg-green-500/10 border-green-500/30"
  defp risk_badge_class("moderate"),
    do: "text-yellow-500 bg-yellow-500/10 border-yellow-500/30"
  defp risk_badge_class("high"),
    do: "text-orange-500 bg-orange-500/10 border-orange-500/30"
  defp risk_badge_class(_),
    do: "text-red-500 bg-red-500/10 border-red-500/30"

  defp risk_text_color("low"), do: "text-green-500"
  defp risk_text_color("moderate"), do: "text-yellow-500"
  defp risk_text_color("high"), do: "text-orange-500"
  defp risk_text_color(_), do: "text-red-500"

  defp parse_params(params) do
    %{
      legs: parse_int(params["legs"], 3),
      min_total_odds: parse_float(params["min_total_odds"], 3.0),
      max_total_odds: parse_float(params["max_total_odds"], 15.0),
      max_single_odd: parse_float(params["max_single_odd"], 3.0)
    }
  end

  defp parse_int(str, default) do
    case Integer.parse(str || "") do
      {v, _} -> v
      :error -> default
    end
  end

  defp parse_float(str, default) do
    case Float.parse(str || "") do
      {v, _} -> v
      :error -> default
    end
  end

  defp upcoming_match_count do
    now = DateTime.utc_now()
    from(f in Fixture, where: f.date > ^now, select: count()) |> Repo.one()
  end
end
