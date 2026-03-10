defmodule BettingEngine.Schemas.ApiSyncLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_sync_logs" do
    field :endpoint, :string
    field :sport_id, :integer
    field :league_id, :integer
    field :params, :map
    field :status, :string
    field :record_count, :integer
    field :error, :string
    field :rate_limit_limit, :integer
    field :rate_limit_remaining, :integer

    timestamps(type: :utc_datetime, inserted_at: :synced_at, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :endpoint,
      :sport_id,
      :league_id,
      :params,
      :status,
      :record_count,
      :error,
      :rate_limit_limit,
      :rate_limit_remaining
    ])
    |> validate_required([:endpoint, :status])
  end
end
