defmodule BettingEngine.Repo.Migrations.CreateSavedBets do
  use Ecto.Migration

  def change do
    create table(:saved_bets) do
      add :fixture_id, references(:fixtures, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :outcome_label, :string, null: false
      add :bookmaker_name, :string, null: false
      add :odds, :float, null: false
      add :stake, :float, null: false
      add :potential_payout, :float
      add :status, :string, default: "Open", null: false

      timestamps(type: :utc_datetime)
    end

    create index(:saved_bets, [:fixture_id])
    create index(:saved_bets, [:status])
    create index(:saved_bets, [:type])
    create index(:saved_bets, [:inserted_at])
  end
end
