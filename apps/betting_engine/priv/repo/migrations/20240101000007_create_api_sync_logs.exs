defmodule BettingEngine.Repo.Migrations.CreateApiSyncLogs do
  use Ecto.Migration

  def change do
    create table(:api_sync_logs) do
      add :endpoint, :string, null: false
      add :sport_id, :integer
      add :league_id, :integer
      # JSONB for request params (flexible auditing)
      add :params, :map
      add :status, :string, null: false
      add :record_count, :integer
      add :error, :text
      add :rate_limit_limit, :integer
      add :rate_limit_remaining, :integer
      add :synced_at, :utc_datetime
    end

    create index(:api_sync_logs, [:endpoint, :synced_at])
    create index(:api_sync_logs, [:sport_id])
    create index(:api_sync_logs, [:synced_at])
  end
end
