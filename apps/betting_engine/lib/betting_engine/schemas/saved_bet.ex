defmodule BettingEngine.Schemas.SavedBet do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_types ["Value", "Surebet", "Parlay"]
  @valid_statuses ["Open", "Won", "Lost"]

  schema "saved_bets" do
    field :type, :string
    field :outcome_label, :string
    field :bookmaker_name, :string
    field :odds, :float
    field :stake, :float
    field :potential_payout, :float
    field :status, :string, default: "Open"

    belongs_to :fixture, BettingEngine.Schemas.Fixture

    timestamps(type: :utc_datetime)
  end

  def changeset(saved_bet, attrs) do
    saved_bet
    |> cast(attrs, [:fixture_id, :type, :outcome_label, :bookmaker_name, :odds, :stake, :potential_payout, :status])
    |> validate_required([:fixture_id, :type, :outcome_label, :bookmaker_name, :odds, :stake])
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:odds, greater_than: 1.0)
    |> validate_number(:stake, greater_than: 0)
    |> put_potential_payout()
    |> foreign_key_constraint(:fixture_id)
  end

  defp put_potential_payout(changeset) do
    odds = get_field(changeset, :odds)
    stake = get_field(changeset, :stake)

    if odds && stake do
      put_change(changeset, :potential_payout, Float.round(odds * stake, 2))
    else
      changeset
    end
  end
end
