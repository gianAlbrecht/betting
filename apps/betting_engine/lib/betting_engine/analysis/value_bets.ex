defmodule BettingEngine.Analysis.ValueBets do
  @moduledoc """
  Finds value bets by comparing bookmaker odds against a de-vigged consensus
  probability derived from the broader market.

  Algorithm per outcome label (e.g. "Arsenal", "Draw", "Chelsea"):
    1. Collect all h2h odds for that label across every bookmaker in the DB.
    2. Average their raw implied probabilities (1/odd). This strips the
       bookmaker margin (vig) via simple averaging — the market consensus.
    3. Calculate edge: edge = consensus_probability × best_available_odd − 1
    4. Surface outcomes where edge ≥ @min_value_threshold (5%).

  Why require @min_bookmakers (2)?
  A single bookmaker's odds cannot be verified against a consensus — you need
  at least two independent quotes to compute a meaningful average. Fixtures
  with only one bookmaker quoting an outcome are silently skipped.

  This module is a pure read-only function; it never writes to the database.
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
    by_label = Enum.group_by(fixture.odds, & &1.label)

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
    # Compute the implied probability for each bookmaker's quote (1/odd),
    # then average them. This is the de-vigged consensus probability — the
    # market's best estimate of the true chance of this outcome occurring.
    raw_probabilities = Enum.map(odds, fn o -> 1 / o.value end)
    total_implied = Enum.sum(raw_probabilities)

    true_probability = total_implied / length(odds)

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
