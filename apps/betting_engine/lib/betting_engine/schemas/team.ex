defmodule BettingEngine.Schemas.Team do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field :api_team_id, :string
    field :name, :string
    field :logo, :string
    field :country, :string

    belongs_to :sport, BettingEngine.Schemas.Sport
    has_many :home_fixtures, BettingEngine.Schemas.Fixture, foreign_key: :home_team_id
    has_many :away_fixtures, BettingEngine.Schemas.Fixture, foreign_key: :away_team_id

    timestamps(type: :utc_datetime)
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:api_team_id, :sport_id, :name, :logo, :country])
    |> validate_required([:api_team_id, :sport_id, :name])
    |> unique_constraint([:api_team_id, :sport_id])
    |> foreign_key_constraint(:sport_id)
  end
end
