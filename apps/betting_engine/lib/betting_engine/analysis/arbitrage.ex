defmodule BettingEngine.Analysis.Arbitrage do
  alias BettingEngine.Repo
  alias BettingEngine.Schemas.Fixture
  import Ecto.Query

  @type arb_outcome :: %{
          label: String.t(),
          best_odd: float(),
          bookmaker: String.t()
        }

  @type surebet :: %{
          fixture_id: integer(),
          date: DateTime.t(),
          home_team: String.t(),
          away_team: String.t(),
          league_name: String.t(),
          league_country: String.t() | nil,
          sport_slug: String.t(),
          arb_margin: float(),
          profit_percent: float(),
          outcomes: %{
            home: arb_outcome(),
            draw: arb_outcome() | nil,
            away: arb_outcome()
          }
        }

  @spec find_opportunities() :: [surebet()]
  def find_opportunities do
    fixtures = load_upcoming_fixtures_with_odds()
    Enum.flat_map(fixtures, &check_fixture/1)
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

  defp check_fixture(fixture) do
    home_name = fixture.home_team.name
    away_name = fixture.away_team.name

    home_odds = Enum.filter(fixture.odds, &(&1.label == home_name))
    draw_odds = Enum.filter(fixture.odds, &(&1.label == "Draw"))
    away_odds = Enum.filter(fixture.odds, &(&1.label == away_name))

    with best_home when not is_nil(best_home) <- best_odd(home_odds),
         best_away when not is_nil(best_away) <- best_odd(away_odds) do
      best_draw = best_odd(draw_odds)

      arb_margin = calc_margin(best_home, best_draw, best_away)

      if arb_margin < 1.0 do
        [
          %{
            fixture_id: fixture.id,
            date: fixture.date,
            home_team: home_name,
            away_team: away_name,
            league_name: fixture.league.name,
            league_country: fixture.league.country,
            sport_slug: fixture.sport.slug,
            arb_margin: Float.round(arb_margin, 4),
            profit_percent: Float.round((1 - arb_margin) * 100, 2),
            outcomes: %{
              home: format_outcome(home_name, best_home),
              draw: best_draw && format_outcome("Draw", best_draw),
              away: format_outcome(away_name, best_away)
            }
          }
        ]
      else
        []
      end
    else
      _ -> []
    end
  end

  defp best_odd([]), do: nil
  defp best_odd(odds), do: Enum.max_by(odds, & &1.value)

  defp calc_margin(home, nil, away) do
    1 / home.value + 1 / away.value
  end

  defp calc_margin(home, draw, away) do
    1 / home.value + 1 / draw.value + 1 / away.value
  end

  defp format_outcome(label, odd) do
    %{label: label, best_odd: odd.value, bookmaker: odd.bookmaker_name}
  end
end
