defmodule BettingEngine.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # All three analysis modules (Arbitrage, ValueBets, Parlay) query odds with
    # WHERE fixture_id = X AND market_name = 'h2h' on every page load. Without
    # this composite index that scan is sequential over the full odds table.
    create index(:odds, [:fixture_id, :market_name])

    # Speeds up the "upcoming fixtures for a league" query used by the sync
    # pipeline when deciding which fixtures to update odds for.
    create index(:fixtures, [:league_id, :date])

    # Partial index covering only status = 'success' rows — the exact predicate
    # used by the 6-hour cache check in OddsApi.Client. Indexing error rows too
    # would double the index size for no benefit since they are never read by
    # the cache check query.
    execute(
      """
      CREATE INDEX api_sync_logs_cache_check_idx
      ON api_sync_logs (endpoint, synced_at DESC)
      WHERE status = 'success'
      """,
      "DROP INDEX IF EXISTS api_sync_logs_cache_check_idx"
    )
  end
end
