defmodule BettingEngine.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Composite index for the most common odds query pattern:
    # WHERE fixture_id = X AND market_name = 'h2h'
    # Used by Arbitrage, ValueBets, and Parlay analysis on every render.
    create index(:odds, [:fixture_id, :market_name])

    # Composite index for league-scoped upcoming fixtures queries.
    create index(:fixtures, [:league_id, :date])

    # Partial index for the 6-hour cache check in OddsApi.Client.
    # The query always filters WHERE status = 'success', so indexing only those rows
    # avoids scanning error/stale rows and keeps the index small.
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
