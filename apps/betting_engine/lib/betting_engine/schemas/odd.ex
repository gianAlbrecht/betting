defmodule BettingEngine.Schemas.Odd do
  use Ecto.Schema
  import Ecto.Changeset

  schema "odds" do
    field :bookmaker_name, :string
    field :market_name, :string
    field :label, :string
    field :value, :float
    field :implied_probability, :float

    belongs_to :fixture, BettingEngine.Schemas.Fixture

    timestamps(type: :utc_datetime, updated_at: :updated_at, inserted_at: :cached_at)
  end

  def changeset(odd, attrs) do
    odd
    |> cast(attrs, [:fixture_id, :bookmaker_name, :market_name, :label, :value, :implied_probability])
    |> validate_required([:fixture_id, :bookmaker_name, :market_name, :label, :value])
    |> validate_number(:value, greater_than: 0)
    |> unique_constraint([:fixture_id, :bookmaker_name, :market_name, :label])
    |> foreign_key_constraint(:fixture_id)
    |> put_implied_probability()
  end

  defp put_implied_probability(changeset) do
    case get_field(changeset, :value) do
      nil -> changeset
      v when v == 0.0 -> changeset
      value -> put_change(changeset, :implied_probability, (1 / value) * 100)
    end
  end
end
