# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Elixir + Phoenix umbrella app that syncs betting odds from The Odds API and performs arbitrage/value/parlay analysis in real time via LiveView.

## Commands

```bash
# Prerequisites
cp .env.example .env          # fill in THE_ODDS_API_KEY
docker compose up -d          # start Postgres 15

# Setup
mix deps.get
mix ecto.setup                # create DB + migrate + seed sports

# Run
mix phx.server                # http://localhost:4000

# Routes
mix phx.routes                # lists all routes (aliased to BettingWeb.Router)

# Tests
mix test                      # all tests
mix test apps/betting_engine/test/path/to/file_test.exs  # single file
mix test apps/betting_engine/test/path/to/file_test.exs:42  # single test

# Database
mix ecto.migrate
mix ecto.reset                # drop + recreate + seed

# Assets (handled automatically by watchers in dev)
mix assets.build              # one-shot compile
mix assets.deploy             # minify + digest for prod

# Force a sync from IEx
BettingEngine.Sync.Poller.sync_now(force: true)
```

## Umbrella structure

```
apps/
  betting_engine/             # OTP app: Ecto, Broadway, analysis logic
    lib/betting_engine/
      analysis/               # Pure stateless modules (arbitrage, value_bets, parlay)
      odds_api/client.ex      # HTTP via Req + 6h cache enforced via ApiSyncLog
      schemas/                # Ecto schemas: Sport → League → Fixture ← Odd, SavedBet
      sync/                   # Broadway pipeline + OddsPoller GenServer
    priv/repo/
      migrations/
      seeds.exs               # Seeds Football + Ice Hockey sports
  betting_web/                # OTP app: Phoenix 1.7 + LiveView
    assets/                   # Source JS/CSS (compiled → priv/static/assets/)
    lib/betting_web/
      live/                   # LiveView modules (dashboard, arbitrage, value_bets, parlay, portfolio)
      components/             # core_components.ex, layouts
config/                       # Shared umbrella config
```

## Architecture

**Sync flow:**
1. `OddsPoller` (GenServer) wakes on `poll_interval_ms` → calls `LeagueProducer.enqueue/1`
2. `LeagueProducer` (GenStage) feeds Broadway
3. `LeaguePipeline` processors (concurrency: 3) call `OddsApi.Client.fetch_odds/1`
4. `OddsApi.Client` checks `ApiSyncLog` — skips API call if fetched within 6h
5. `:db` batcher (concurrency: 1) upserts via `SportsSync.upsert_league_events/2`
6. Each successful upsert broadcasts `{:odds_updated, stats}` on `"odds:updated"` PubSub topic
7. LiveViews subscribed on mount re-run analysis and push diffs

**LiveView pattern:** All LiveViews subscribe to `"odds:updated"` in `mount/3`. Heavy computation (parlay combos) runs in `Task.Supervisor` to avoid blocking the LiveView process.

**Analysis modules** (`BettingEngine.Analysis.*`) are pure functions with no side effects:
- `Arbitrage` — finds surebets where arb_margin < 1.0
- `ValueBets` — de-vigged consensus odds, surfaces edges > 5%
- `Parlay` — N-leg combo generator, capped at 10k combinations

**PubSub topics:** `"odds:updated"`, `"sync:status"`

## Key configuration

Leagues are defined in `config/config.exs` under `:betting_engine, :leagues` (12 leagues: 9 football, 3 ice hockey).

Sync rate-limit settings (`:betting_engine, :sync`):
- `poll_interval_ms` — 30 min in dev, 6h in prod
- `monthly_request_limit` — 500 (free tier)

Asset pipeline: esbuild 0.25 + Tailwind 4 with dev watchers configured in `config/dev.exs`.

## Environment variables

| Variable | Required | Notes |
|---|---|---|
| `THE_ODDS_API_KEY` | Always | Primary data source |
| `SECRET_KEY_BASE` | Prod only | `mix phx.gen.secret` |
| `DATABASE_URL` | Prod only | `ecto://user:pass@host/db` |
| `DB_USER/PASSWORD/HOST/NAME/PORT` | Dev only | Defaults to postgres/postgres/localhost |
