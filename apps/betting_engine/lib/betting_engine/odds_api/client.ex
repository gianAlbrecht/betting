defmodule BettingEngine.OddsApi.Client do
  require Logger

  alias BettingEngine.Repo
  alias BettingEngine.Schemas.ApiSyncLog
  import Ecto.Query

  @base_url "https://api.the-odds-api.com/v4"
  @cache_ttl_hours 6

  @type rate_limit :: %{limit: integer(), remaining: integer()}
  @type event :: map()

  @spec fetch_odds(map(), keyword()) ::
          {:ok, [event()], rate_limit() | nil}
          | {:cached, non_neg_integer()}
          | {:error, String.t()}
  def fetch_odds(league_config, opts \\ []) do
    force = Keyword.get(opts, :force, false)
    sport_key = league_config.key
    endpoint = "/sports/#{sport_key}/odds/"
    cache_key = "#{endpoint}?regions=eu&markets=h2h"

    with :ok <- maybe_check_cache(cache_key, force) do
      do_request(endpoint, cache_key, league_config, opts)
    end
  end

  defp maybe_check_cache(_cache_key, true), do: :ok

  defp maybe_check_cache(cache_key, false) do
    cutoff = DateTime.add(DateTime.utc_now(), -@cache_ttl_hours * 3600, :second)

    recent =
      from(l in ApiSyncLog,
        where:
          l.endpoint == ^cache_key and
            l.status == "success" and
            l.synced_at >= ^cutoff,
        order_by: [desc: l.synced_at],
        limit: 1,
        select: l.record_count
      )
      |> Repo.one()

    case recent do
      nil -> :ok
      count -> {:cached, count || 0}
    end
  end

  defp do_request(endpoint, cache_key, league_config, _opts) do
    api_key = Application.fetch_env!(:betting_engine, :odds_api_key)
    url = @base_url <> endpoint

    Logger.info("[OddsClient] → GET #{url} (#{league_config.name})")

    case Req.get(url,
           params: [apiKey: api_key, regions: "eu", markets: "h2h", oddsFormat: "decimal"],
           receive_timeout: 30_000
         ) do
      {:ok, %{status: 200, body: events, headers: headers}} when is_list(events) ->
        rate_limit = parse_rate_limit(headers)
        Logger.info("[OddsClient] ✓ #{league_config.name}: #{length(events)} events (#{rate_limit && rate_limit.remaining || "?"} requests remaining)")
        log_sync(cache_key, "success", length(events), nil, league_config, rate_limit)
        {:ok, events, rate_limit}

      {:ok, %{status: 200, body: body}} ->
        error = "Unexpected response body (not a list): #{inspect(body)}"
        Logger.error("[OddsClient] ✗ #{league_config.name}: #{error}")
        broadcast_error(league_config.name, error)
        log_sync(cache_key, "error", nil, error, league_config, nil)
        {:error, error}

      {:ok, %{status: 401}} ->
        error = "HTTP 401 Unauthorized — check THE_ODDS_API_KEY"
        Logger.error("[OddsClient] ✗ #{league_config.name}: #{error}")
        broadcast_error(league_config.name, error)
        log_sync(cache_key, "error", nil, error, league_config, nil)
        {:error, error}

      {:ok, %{status: 429}} ->
        error = "HTTP 429 Rate limit exceeded — monthly quota used up"
        Logger.error("[OddsClient] ✗ #{league_config.name}: #{error}")
        broadcast_error(league_config.name, error)
        log_sync(cache_key, "error", nil, error, league_config, nil)
        {:error, error}

      {:ok, %{status: status, body: body}} ->
        error = "HTTP #{status}: #{inspect(body)}"
        Logger.error("[OddsClient] ✗ #{league_config.name}: #{error}")
        broadcast_error(league_config.name, error)
        log_sync(cache_key, "error", nil, error, league_config, nil)
        {:error, error}

      {:error, exception} ->
        error = "Network error: #{Exception.message(exception)}"
        Logger.error("[OddsClient] ✗ #{league_config.name}: #{error}")
        broadcast_error(league_config.name, error)
        log_sync(cache_key, "error", nil, error, league_config, nil)
        {:error, error}
    end
  end

  defp broadcast_error(league_name, error) do
    Phoenix.PubSub.broadcast(
      BettingEngine.PubSub,
      "sync:status",
      {:sync_error, %{league: league_name, error: error}}
    )
  end

  defp parse_rate_limit(headers) do
    with remaining when not is_nil(remaining) <- get_header(headers, "x-requests-remaining"),
         used when not is_nil(used) <- get_header(headers, "x-requests-used"),
         {remaining_int, _} <- Integer.parse(remaining),
         {used_int, _} <- Integer.parse(used) do
      %{limit: remaining_int + used_int, remaining: remaining_int}
    else
      _ -> nil
    end
  end

  defp get_header(headers, name) when is_map(headers) do
    case Map.get(headers, name) do
      [value | _] -> value
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  defp get_header(headers, name) when is_list(headers) do
    case List.keyfind(headers, name, 0) do
      {_, value} -> value
      nil -> nil
    end
  end

  defp log_sync(cache_key, status, record_count, error, league_config, rate_limit) do
    attrs = %{
      endpoint: cache_key,
      sport_id: Map.get(league_config, :sport_db_id),
      league_id: Map.get(league_config, :league_db_id),
      params: %{key: league_config.key},
      status: status,
      record_count: record_count,
      error: error,
      rate_limit_limit: rate_limit && rate_limit.limit,
      rate_limit_remaining: rate_limit && rate_limit.remaining
    }

    %ApiSyncLog{}
    |> ApiSyncLog.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, _} -> :ok
      {:error, err} -> Logger.warning("Failed to write sync log: #{inspect(err)}")
    end
  end

  @spec monthly_requests_used() :: non_neg_integer()
  def monthly_requests_used do
    month_start = DateTime.new!(Date.beginning_of_month(Date.utc_today()), ~T[00:00:00], "Etc/UTC")

    from(l in ApiSyncLog,
      where: l.status == "success" and l.synced_at >= ^month_start,
      select: count()
    )
    |> Repo.one()
  end

  @spec recent_sync_logs(pos_integer()) :: [ApiSyncLog.t()]
  def recent_sync_logs(limit \\ 15) do
    from(l in ApiSyncLog,
      order_by: [desc: l.synced_at],
      limit: ^limit
    )
    |> Repo.all()
  end
end
