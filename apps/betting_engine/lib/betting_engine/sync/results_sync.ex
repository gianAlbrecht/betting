defmodule BettingEngine.Sync.ResultsSync do
  require Logger

  import Ecto.Query

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.Fixture
  alias BettingEngine.SportsApi.Client, as: SportsClient

  def sync_results do
    leagues = leagues_needing_results()

    if leagues == [] do
      Logger.debug("[ResultsSync] Nothing to sync")
      :ok
    else
      Logger.info("[ResultsSync] #{length(leagues)} league(s) with pending results")
      updated_total = Enum.sum(Enum.map(leagues, &sync_league/1))

      if updated_total > 0 do
        Phoenix.PubSub.broadcast(
          BettingEngine.PubSub,
          "results:updated",
          {:results_updated, %{count: updated_total}}
        )

        Logger.info("[ResultsSync] Applied #{updated_total} result(s)")
      end

      :ok
    end
  end

  defp sync_league(league_config) do
    today = Date.utc_today()
    yesterday = Date.add(today, -1)

    api_results =
      [yesterday, today]
      |> Enum.flat_map(fn date ->
        case SportsClient.fetch_results(league_config, date) do
          {:ok, results} ->
            results

          {:disabled, msg} ->
            Logger.debug("[ResultsSync] #{msg}")
            []

          {:error, reason} ->
            Logger.warning("[ResultsSync] #{league_config.name} (#{date}): #{reason}")
            []
        end
      end)
      |> Enum.filter(&finished?/1)

    if api_results == [] do
      0
    else
      apply_results_to_league(league_config, api_results)
    end
  end

  defp apply_results_to_league(league_config, api_results) do
    now = DateTime.utc_now()
    week_ago = DateTime.add(now, -7 * 24 * 3600, :second)

    our_fixtures =
      from(f in Fixture,
        join: l in assoc(f, :league),
        join: ht in assoc(f, :home_team),
        join: at in assoc(f, :away_team),
        where: l.name == ^league_config.name,
        where: f.date < ^now,
        where: f.date > ^week_ago,
        where: is_nil(f.home_score),
        preload: [home_team: ht, away_team: at]
      )
      |> Repo.all()

    Enum.count(our_fixtures, fn fixture ->
      case find_match(fixture, api_results) do
        nil -> false
        result -> apply_result(fixture, result)
      end
    end)
  end

  defp find_match(fixture, api_results) do
    our_home = normalize(fixture.home_team.name)
    our_away = normalize(fixture.away_team.name)

    Enum.find(api_results, fn r ->
      api_home = normalize(r.home_team)
      api_away = normalize(r.away_team)

      (api_home == our_home and api_away == our_away) or
        (String.contains?(api_home, our_home) and String.contains?(api_away, our_away)) or
        (String.contains?(our_home, api_home) and String.contains?(our_away, api_away))
    end)
  end

  defp normalize(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\b(fc|sc|ac|cf|afc|bsc|sv|vfb|tsv|rb|vfl|fsv|ss|as|rc|if|ik|hv)\b/, "")
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp apply_result(fixture, result) do
    changeset =
      Ecto.Changeset.change(fixture, %{
        home_score: result.home_score,
        away_score: result.away_score,
        status: result.status,
        status_short: result.status_short
      })

    case Repo.update(changeset) do
      {:ok, _} ->
        Logger.info(
          "[ResultsSync] #{fixture.home_team.name} #{result.home_score}–#{result.away_score} #{fixture.away_team.name} (#{result.status_short})"
        )

        true

      {:error, changeset} ->
        Logger.error(
          "[ResultsSync] Failed to update fixture #{fixture.id}: #{inspect(changeset.errors)}"
        )

        false
    end
  end

  defp finished?(%{status_short: s}) when s in ~w(FT AET PEN HT 1H 2H ET BT), do: s in ~w(FT AET PEN)
  defp finished?(_), do: false

  defp leagues_needing_results do
    now = DateTime.utc_now()
    week_ago = DateTime.add(now, -7 * 24 * 3600, :second)

    active_league_names =
      from(f in Fixture,
        join: l in assoc(f, :league),
        where: f.date < ^now,
        where: f.date > ^week_ago,
        where: is_nil(f.home_score),
        select: l.name,
        distinct: true
      )
      |> Repo.all()

    Application.get_env(:betting_engine, :leagues, [])
    |> Enum.filter(fn league ->
      Map.has_key?(league, :api_sports_league_id) and
        league.name in active_league_names
    end)
  end
end
