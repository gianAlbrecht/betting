defmodule BettingEngine.Repo.Migrations.CreateSports do
  use Ecto.Migration

  def change do
    create table(:sports) do
      add :api_sport_id, :string, null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sports, [:slug])
    create unique_index(:sports, [:api_sport_id])
  end
end
