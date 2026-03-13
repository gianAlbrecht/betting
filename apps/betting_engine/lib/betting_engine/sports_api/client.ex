defmodule BettingEngine.SportsApi.Client do
  require Logger

  @football_base "https://v3.football.api-sports.io"
  @hockey_base "https://v1.hockey.api-sports.io"

  @type game_result :: %{
          home_team: String.t(),
          away_team: String.t(),
          home_score: non_neg_integer() | nil,
          away_score: non_neg_integer() | nil,
          status: String.t(),
          status_short: String.t()
        }

  @spec fetch_results(map(), Date.t()) ::
          {:ok, [game_result()]}
          | {:disabled, String.t()}
          | {:error, String.t()}
  def fetch_results(league_config, date \\ Date.utc_today()) do
    case api_key() do
      nil ->
        {:disabled, "API_SPORTS_KEY not configured — skipping results sync"}

      key ->
        do_fetch(league_config, date, key)
    end
  end

  defp do_fetch(league_config, date, api_key) do
    {base_url, endpoint, params} = build_request(league_config, date)
    url = base_url <> endpoint

    Logger.info("[SportsApi] → GET #{url} (#{league_config.name}, #{date})")

    headers = [{"x-apisports-key", api_key}]

    case Req.get(url, params: params, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"errors" => errors}}} when map_size(errors) > 0 ->
        msg = errors |> Map.values() |> Enum.join("; ")
        Logger.warning("[SportsApi] API error for #{league_config.name}: #{msg}")
        {:error, msg}

      {:ok, %{status: 200, body: %{"response" => items}}} when is_list(items) ->
        Logger.info("[SportsApi] ✓ #{league_config.name}: #{length(items)} games returned")
        {:ok, Enum.map(items, &parse_result(league_config.sport_slug, &1))}

      {:ok, %{status: 401}} ->
        {:error, "HTTP 401 — check API_SPORTS_KEY"}

      {:ok, %{status: 429}} ->
        {:error, "HTTP 429 — daily quota exceeded"}

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, exception} ->
        {:error, "Network error: #{Exception.message(exception)}"}
    end
  end

  defp build_request(%{sport_slug: slug} = config, date)
       when slug in ["football", "soccer"] do
    params = [
      league: config.api_sports_league_id,
      season: current_football_season(),
      date: Date.to_iso8601(date)
    ]

    {@football_base, "/fixtures", params}
  end

  defp build_request(%{sport_slug: slug} = config, date)
       when slug in ["icehockey", "ice_hockey", "hockey"] do
    params = [
      league: config.api_sports_league_id,
      season: current_hockey_season(),
      date: Date.to_iso8601(date)
    ]

    {@hockey_base, "/games", params}
  end

  defp parse_result(slug, item) when slug in ["football", "soccer"] do
    home_team = get_in(item, ["teams", "home", "name"]) || ""
    away_team = get_in(item, ["teams", "away", "name"]) || ""
    home_score = get_in(item, ["goals", "home"])
    away_score = get_in(item, ["goals", "away"])
    status = get_in(item, ["fixture", "status", "long"]) || ""
    status_short = get_in(item, ["fixture", "status", "short"]) || ""

    %{
      home_team: home_team,
      away_team: away_team,
      home_score: home_score,
      away_score: away_score,
      status: status,
      status_short: status_short
    }
  end

  defp parse_result(_slug, item) do
    home_team = get_in(item, ["teams", "home", "name"]) || ""
    away_team = get_in(item, ["teams", "away", "name"]) || ""
    home_score = get_in(item, ["scores", "home"])
    away_score = get_in(item, ["scores", "away"])
    status = get_in(item, ["status", "long"]) || ""
    status_short = get_in(item, ["status", "short"]) || ""

    %{
      home_team: home_team,
      away_team: away_team,
      home_score: home_score,
      away_score: away_score,
      status: status,
      status_short: status_short
    }
  end

  defp current_football_season do
    today = Date.utc_today()
    if today.month >= 8, do: today.year, else: today.year - 1
  end

  defp current_hockey_season do
    today = Date.utc_today()
    if today.month >= 9, do: today.year, else: today.year - 1
  end

  defp api_key, do: Application.get_env(:betting_engine, :sports_api_key)
end
