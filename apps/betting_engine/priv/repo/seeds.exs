alias BettingEngine.Repo
alias BettingEngine.Schemas.Sport

sports = [
  %{api_sport_id: "football", name: "Football", slug: "football"},
  %{api_sport_id: "icehockey", name: "Ice Hockey", slug: "icehockey"}
]

for sport_attrs <- sports do
  %Sport{}
  |> Sport.changeset(sport_attrs)
  |> Repo.insert(on_conflict: :nothing, conflict_target: :slug)
end

IO.puts("Seeds complete.")
