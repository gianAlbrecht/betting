defmodule BettingEngine.Sync.SportsSync do
  require Logger

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.{Sport, League, Team, Fixture, Odd}

  @type upsert_stats :: %{fixtures: non_neg_integer(), odds: non_neg_integer()}

  @spec upsert_league_events(map(), [map()]) :: {:ok, upsert_stats()} | {:error, term()}
  def upsert_league_events(league_config, events) do
    Repo.transaction(fn ->
      sport = upsert_sport!(league_config.sport_slug, league_config.sport_name)
      league = upsert_league!(sport.id, league_config.key, league_config.name)

      stats = %{fixtures: 0, odds: 0}

      Enum.reduce(events, stats, fn event, acc ->
        home_team = upsert_team!(sport.id, event["home_team"])
        away_team = upsert_team!(sport.id, event["away_team"])

        fixture = upsert_fixture!(sport.id, league.id, home_team.id, away_team.id, event)
        odds_count = upsert_odds!(fixture.id, event["bookmakers"])

        %{acc | fixtures: acc.fixtures + 1, odds: acc.odds + odds_count}
      end)
    end)
  end

  defp upsert_sport!(slug, name) do
    now = DateTime.utc_now(:second)

    Repo.insert!(
      %Sport{
        api_sport_id: slug,
        name: name,
        slug: slug,
        inserted_at: now,
        updated_at: now
      },
      on_conflict: [set: [name: name, updated_at: now]],
      conflict_target: :slug,
      returning: true
    )
  end

  defp upsert_league!(sport_id, api_league_id, name) do
    now = DateTime.utc_now(:second)

    Repo.insert!(
      %League{
        api_league_id: api_league_id,
        sport_id: sport_id,
        name: name,
        inserted_at: now,
        updated_at: now
      },
      on_conflict: [set: [name: name, updated_at: now]],
      conflict_target: [:api_league_id, :sport_id],
      returning: true
    )
  end

  defp upsert_team!(sport_id, team_name) do
    now = DateTime.utc_now(:second)

    Repo.insert!(
      %Team{
        api_team_id: team_name,
        sport_id: sport_id,
        name: team_name,
        inserted_at: now,
        updated_at: now
      },
      on_conflict: [set: [name: team_name, updated_at: now]],
      conflict_target: [:api_team_id, :sport_id],
      returning: true
    )
  end

  defp upsert_fixture!(sport_id, league_id, home_team_id, away_team_id, event) do
    commence = parse_datetime!(event["commence_time"])
    now = DateTime.utc_now(:second)
    status = if DateTime.compare(commence, now) == :gt, do: "Not Started", else: "In Play"
    status_short = if status == "Not Started", do: "NS", else: "LIVE"

    Repo.insert!(
      %Fixture{
        api_fixture_id: event["id"],
        sport_id: sport_id,
        league_id: league_id,
        home_team_id: home_team_id,
        away_team_id: away_team_id,
        date: commence,
        timestamp: DateTime.to_unix(commence),
        status: status,
        status_short: status_short,
        inserted_at: now,
        updated_at: now
      },
      on_conflict: [
        set: [
          date: commence,
          timestamp: DateTime.to_unix(commence),
          status: status,
          status_short: status_short,
          updated_at: now
        ]
      ],
      conflict_target: [:api_fixture_id, :sport_id],
      returning: true
    )
  end

  defp upsert_odds!(_fixture_id, nil), do: 0

  defp upsert_odds!(fixture_id, bookmakers) when is_list(bookmakers) do
    now = DateTime.utc_now(:second)

    rows =
      for bookmaker <- bookmakers,
          market <- bookmaker["markets"] || [],
          outcome <- market["outcomes"] || [],
          price = outcome["price"],
          is_number(price) and price > 0 do
        %{
          fixture_id: fixture_id,
          bookmaker_name: bookmaker["title"],
          market_name: market["key"],
          label: outcome["name"],
          value: price,
          implied_probability: 1 / price * 100,
          cached_at: now,
          updated_at: now
        }
      end

    {count, _} =
      Repo.insert_all(Odd, rows,
        on_conflict: {:replace, [:value, :implied_probability, :updated_at]},
        conflict_target: [:fixture_id, :bookmaker_name, :market_name, :label]
      )

    count
  end

  defp parse_datetime!(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :second)
      {:error, reason} -> raise "Failed to parse datetime #{iso_string}: #{inspect(reason)}"
    end
  end
end
