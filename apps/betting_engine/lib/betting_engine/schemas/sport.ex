defmodule BettingEngine.Schemas.Sport do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sports" do
    field :api_sport_id, :string
    field :name, :string
    field :slug, :string
    field :active, :boolean, default: true

    has_many :leagues, BettingEngine.Schemas.League
    has_many :teams, BettingEngine.Schemas.Team
    has_many :fixtures, BettingEngine.Schemas.Fixture

    timestamps(type: :utc_datetime)
  end

  def changeset(sport, attrs) do
    sport
    |> cast(attrs, [:api_sport_id, :name, :slug, :active])
    |> validate_required([:api_sport_id, :name, :slug])
    |> unique_constraint(:slug)
    |> unique_constraint(:api_sport_id)
  end
end
