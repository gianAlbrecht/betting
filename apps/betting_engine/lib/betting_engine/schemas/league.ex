defmodule BettingEngine.Schemas.League do
  use Ecto.Schema
  import Ecto.Changeset

  schema "leagues" do
    field :api_league_id, :string
    field :name, :string
    field :country, :string
    field :country_code, :string
    field :logo, :string
    field :season, :integer
    field :active, :boolean, default: true

    belongs_to :sport, BettingEngine.Schemas.Sport
    has_many :fixtures, BettingEngine.Schemas.Fixture

    timestamps(type: :utc_datetime)
  end

  def changeset(league, attrs) do
    league
    |> cast(attrs, [:api_league_id, :sport_id, :name, :country, :country_code, :logo, :season, :active])
    |> validate_required([:api_league_id, :sport_id, :name])
    |> unique_constraint([:api_league_id, :sport_id])
    |> foreign_key_constraint(:sport_id)
  end
end
