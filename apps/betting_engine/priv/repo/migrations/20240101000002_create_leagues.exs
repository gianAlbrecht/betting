defmodule BettingEngine.Repo.Migrations.CreateLeagues do
  use Ecto.Migration

  def change do
    create table(:leagues) do
      add :api_league_id, :string, null: false
      add :sport_id, references(:sports, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :country, :string
      add :country_code, :string
      add :logo, :string
      add :season, :integer
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:leagues, [:api_league_id, :sport_id])
    create index(:leagues, [:sport_id])
  end
end
