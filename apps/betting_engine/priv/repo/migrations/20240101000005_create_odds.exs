defmodule BettingEngine.Repo.Migrations.CreateOdds do
  use Ecto.Migration

  def change do
    create table(:odds) do
      add :fixture_id, references(:fixtures, on_delete: :delete_all), null: false
      add :bookmaker_name, :string, null: false
      add :market_name, :string, null: false
      add :label, :string, null: false
      add :value, :float, null: false
      add :implied_probability, :float

      # cached_at tracks when this odd was last fetched from the API
      add :cached_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create unique_index(:odds, [:fixture_id, :bookmaker_name, :market_name, :label])
    create index(:odds, [:fixture_id])
    create index(:odds, [:market_name])
    # GIN index for fast filtering on value ranges
    create index(:odds, [:value])
  end
end
