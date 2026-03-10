defmodule BettingEngine.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :api_team_id, :string, null: false
      add :sport_id, references(:sports, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :logo, :string
      add :country, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:teams, [:api_team_id, :sport_id])
    create index(:teams, [:sport_id])
  end
end
