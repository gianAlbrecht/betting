defmodule BettingEngine.Repo.Migrations.CreateFixtures do
  use Ecto.Migration

  def change do
    create table(:fixtures) do
      add :api_fixture_id, :string, null: false
      add :sport_id, references(:sports, on_delete: :delete_all), null: false
      add :league_id, references(:leagues, on_delete: :delete_all), null: false
      add :home_team_id, references(:teams, on_delete: :delete_all), null: false
      add :away_team_id, references(:teams, on_delete: :delete_all), null: false
      add :date, :utc_datetime, null: false
      add :timestamp, :integer
      add :status, :string, null: false
      add :status_short, :string
      add :venue, :string
      add :round, :string
      add :home_score, :integer
      add :away_score, :integer
      add :elapsed, :integer
      # JSONB for sport-specific data (period scores, shootout results, etc.)
      add :sport_specific_data, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:fixtures, [:api_fixture_id, :sport_id])
    create index(:fixtures, [:sport_id])
    create index(:fixtures, [:league_id])
    create index(:fixtures, [:date])
    create index(:fixtures, [:status])
    create index(:fixtures, [:home_team_id])
    create index(:fixtures, [:away_team_id])
  end
end
