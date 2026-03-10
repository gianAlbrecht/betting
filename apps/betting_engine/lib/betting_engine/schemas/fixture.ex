defmodule BettingEngine.Schemas.Fixture do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fixtures" do
    field :api_fixture_id, :string
    field :date, :utc_datetime
    field :timestamp, :integer
    field :status, :string
    field :status_short, :string
    field :venue, :string
    field :round, :string
    field :home_score, :integer
    field :away_score, :integer
    field :elapsed, :integer
    field :sport_specific_data, :map

    belongs_to :sport, BettingEngine.Schemas.Sport
    belongs_to :league, BettingEngine.Schemas.League
    belongs_to :home_team, BettingEngine.Schemas.Team
    belongs_to :away_team, BettingEngine.Schemas.Team

    has_many :odds, BettingEngine.Schemas.Odd
    has_many :saved_bets, BettingEngine.Schemas.SavedBet

    timestamps(type: :utc_datetime)
  end

  def changeset(fixture, attrs) do
    fixture
    |> cast(attrs, [
      :api_fixture_id,
      :sport_id,
      :league_id,
      :home_team_id,
      :away_team_id,
      :date,
      :timestamp,
      :status,
      :status_short,
      :venue,
      :round,
      :home_score,
      :away_score,
      :elapsed,
      :sport_specific_data
    ])
    |> validate_required([:api_fixture_id, :sport_id, :league_id, :home_team_id, :away_team_id, :date, :status])
    |> unique_constraint([:api_fixture_id, :sport_id])
    |> foreign_key_constraint(:sport_id)
    |> foreign_key_constraint(:league_id)
    |> foreign_key_constraint(:home_team_id)
    |> foreign_key_constraint(:away_team_id)
  end
end
