defmodule BettingEngine.Analysis.Parlay do
  @moduledoc """
  Generates optimal parlay combinations from upcoming fixtures.

  Params: legs, min_total_odds, max_total_odds, max_single_odd
  Ranks by implied probability descending. Caps at 10k combinations checked.

  Risk levels (based on implied probability):
    - low:      > 55%
    - moderate: > 30%
    - high:     > 10%
    - extreme:  ≤ 10%
  """

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.Fixture
  import Ecto.Query

  @max_combinations 10_000
  @max_valid 50
  @max_results 10

  @type parlay_leg :: %{
          fixture_id: integer(),
          home_team: String.t(),
          away_team: String.t(),
          date: DateTime.t(),
          league_name: String.t(),
          pick: String.t(),
          odd: float(),
          bookmaker: String.t()
        }

  @type parlay :: %{
          legs: [parlay_leg()],
          combined_odd: float(),
          implied_probability: float(),
          risk_level: String.t()
        }

  @type params :: %{
          legs: pos_integer(),
          min_total_odds: float(),
          max_total_odds: float(),
          max_single_odd: float()
        }

  @spec generate(params()) :: [parlay()]
  def generate(%{
        legs: legs,
        min_total_odds: min_total_odds,
        max_total_odds: max_total_odds,
        max_single_odd: max_single_odd
      }) do
    fixtures = load_fixtures_with_best_odds(max_single_odd)

    if length(fixtures) < legs do
      []
    else
      fixtures
      |> pick_combinations(legs)
      |> filter_by_odds_range(min_total_odds, max_total_odds)
      |> Enum.take(@max_valid)
      |> Enum.map(&build_parlay/1)
      |> Enum.sort_by(& &1.implied_probability, :desc)
      |> Enum.take(@max_results)
    end
  end

  # ─── Private ─────────────────────────────────────────────

  defp load_fixtures_with_best_odds(max_single_odd) do
    now = DateTime.utc_now()

    from(f in Fixture,
      where: f.date > ^now,
      join: l in assoc(f, :league),
      join: ht in assoc(f, :home_team),
      join: at in assoc(f, :away_team),
      join: o in assoc(f, :odds),
      where: o.market_name == "h2h" and o.value <= ^max_single_odd,
      preload: [league: l, home_team: ht, away_team: at, odds: o],
      order_by: [asc: f.date],
      limit: 50
    )
    |> Repo.all()
    |> Enum.map(&build_fixture_picks/1)
    |> Enum.filter(&(length(&1.picks) > 0))
  end

  defp build_fixture_picks(fixture) do
    home_name = fixture.home_team.name
    away_name = fixture.away_team.name

    picks =
      [home_name, "Draw", away_name]
      |> Enum.map(fn label ->
        matching = Enum.filter(fixture.odds, &(&1.label == label))

        case Enum.max_by(matching, & &1.value, fn -> nil end) do
          nil -> nil
          best -> %{pick: label, odd: best.value, bookmaker: best.bookmaker_name}
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.odd)

    %{
      fixture_id: fixture.id,
      home_team: home_name,
      away_team: away_name,
      date: fixture.date,
      league_name: fixture.league.name,
      picks: picks,
      min_odd: picks |> Enum.map(& &1.odd) |> Enum.min(fn -> 0 end)
    }
  end

  defp pick_combinations(fixtures, legs) do
    fixture_pick_pairs =
      Enum.flat_map(fixtures, fn f ->
        Enum.map(f.picks, fn p -> Map.merge(f, p) |> Map.delete(:picks) |> Map.delete(:min_odd) end)
      end)

    fixture_pick_pairs
    |> combinations(legs)
    |> Stream.take(@max_combinations)
    |> Enum.to_list()
  end

  defp combinations(_, 0), do: [[]]
  defp combinations([], _), do: []

  defp combinations([h | t], n) do
    with_h = for combo <- combinations(t, n - 1), do: [h | combo]
    without_h = combinations(t, n)
    with_h ++ without_h
  end

  defp filter_by_odds_range(combinations, min_odd, max_odd) do
    Enum.filter(combinations, fn legs ->
      combined = Enum.reduce(legs, 1.0, fn leg, acc -> acc * leg.odd end)
      combined >= min_odd and combined <= max_odd
    end)
  end

  defp build_parlay(legs) do
    combined_odd =
      legs
      |> Enum.reduce(1.0, fn leg, acc -> acc * leg.odd end)
      |> Float.round(2)

    implied_probability = Float.round(1 / combined_odd * 100, 2)

    %{
      legs:
        Enum.map(
          legs,
          &Map.take(&1, [:fixture_id, :home_team, :away_team, :date, :league_name, :pick, :odd, :bookmaker])
        ),
      combined_odd: combined_odd,
      implied_probability: implied_probability,
      risk_level: risk_level(implied_probability)
    }
  end

  defp risk_level(implied_prob) when implied_prob > 55, do: "low"
  defp risk_level(implied_prob) when implied_prob > 30, do: "moderate"
  defp risk_level(implied_prob) when implied_prob > 10, do: "high"
  defp risk_level(_), do: "extreme"
end
