defmodule BettingEngine.Analysis.ValueBets do
  @moduledoc """
  Identifies value bets based on market efficiency.

  A value bet exists when a bookmaker's implied probability is LOWER than
  the "true" probability estimated from the market consensus (average implied prob
  across all bookmakers, de-vigged).

  value = (true_probability * odd) - 1
  A positive value means the bet has positive expected value (+EV).

  Threshold: only bets with value > 0.05 (5% edge) are surfaced.
  """

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.Fixture
  import Ecto.Query

  @min_value_threshold 0.05
  @min_bookmakers 2

  @type value_outcome :: %{
          label: String.t(),
          bookmaker: String.t(),
          odd: float(),
          implied_probability: float(),
          true_probability: float(),
          value: float()
        }

  @type value_fixture :: %{
          fixture_id: integer(),
          date: DateTime.t(),
          home_team: String.t(),
          away_team: String.t(),
          sport_slug: String.t(),
          league_name: String.t(),
          value_outcomes: [value_outcome()]
        }

  @spec find_value_bets() :: [value_fixture()]
  def find_value_bets do
    fixtures = load_upcoming_fixtures_with_odds()

    fixtures
    |> Enum.map(&analyze_fixture/1)
    |> Enum.filter(&(length(&1.value_outcomes) > 0))
  end

  # ─── Private ─────────────────────────────────────────────

  defp load_upcoming_fixtures_with_odds do
    now = DateTime.utc_now()

    from(f in Fixture,
      where: f.date > ^now,
      join: s in assoc(f, :sport),
      join: l in assoc(f, :league),
      join: ht in assoc(f, :home_team),
      join: at in assoc(f, :away_team),
      join: o in assoc(f, :odds),
      where: o.market_name == "h2h",
      preload: [
        sport: s,
        league: l,
        home_team: ht,
        away_team: at,
        odds: o
      ]
    )
    |> Repo.all()
  end

  defp analyze_fixture(fixture) do
    # Group odds by outcome label
    by_label = Enum.group_by(fixture.odds, & &1.label)

    # Need at least @min_bookmakers per outcome for a meaningful consensus
    value_outcomes =
      by_label
      |> Enum.filter(fn {_, odds} -> length(odds) >= @min_bookmakers end)
      |> Enum.flat_map(fn {label, odds} -> find_value_for_outcome(label, odds) end)

    %{
      fixture_id: fixture.id,
      date: fixture.date,
      home_team: fixture.home_team.name,
      away_team: fixture.away_team.name,
      sport_slug: fixture.sport.slug,
      league_name: fixture.league.name,
      value_outcomes: value_outcomes
    }
  end

  defp find_value_for_outcome(label, odds) do
    # Implied probability per bookmaker for this outcome
    raw_probabilities = Enum.map(odds, fn o -> 1 / o.value end)
    total_implied = Enum.sum(raw_probabilities)

    # Market consensus: simple average of implied probabilities across bookmakers.
    # This approximates the "true" probability by averaging out individual bookmaker bias.
    # Note: this includes residual vig; a full de-vig requires all outcomes per bookmaker.
    true_probability = total_implied / length(odds)

    # Find bookmaker with the highest odds (best overlay)
    best = Enum.max_by(odds, & &1.value)
    value = true_probability * best.value - 1

    if value >= @min_value_threshold do
      [
        %{
          label: label,
          bookmaker: best.bookmaker_name,
          odd: Float.round(best.value, 2),
          implied_probability: Float.round((1 / best.value) * 100, 2),
          true_probability: Float.round(true_probability * 100, 2),
          value: Float.round(value * 100, 2)
        }
      ]
    else
      []
    end
  end
end
