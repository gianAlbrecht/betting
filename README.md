## Phoenix Betting – Developer Guide

This is a Phoenix umbrella app (`betting_engine` + `betting_web`) that syncs betting odds from The Odds API and runs arbitrage / value / parlay analysis in real time via LiveView.

### Tech stack
- **Backend**: Elixir, Phoenix 1.7, LiveView, Ecto, Broadway
- **Database**: PostgreSQL 15
- **HTTP client**: Req

---

## Prerequisites

- **Elixir & Erlang** installed (recommended via `asdf`)
- **PostgreSQL 15+** (or use Docker, see below)
- **Node.js** (for asset building, usually handled by Phoenix)

Environment:

- Copy env file and set your API key:

```bash
cp .env.example .env
```

- Also a envrc is needed it only needs to contain this:

```bash
dotenv
```

Key env vars:

- **`THE_ODDS_API_KEY`** (required, all envs)
- **`SECRET_KEY_BASE`** (required in prod: `mix phx.gen.secret`)
- **`DATABASE_URL`** (prod)
- **`DB_USER` / `DB_PASSWORD` / `DB_HOST` / `DB_NAME` / `DB_PORT`** (dev; defaults in `.env.example`)

---

## Running with Docker (recommended for Postgres)

### Start PostgreSQL via Docker Compose

From the repo root:

```bash
docker compose up -d
```

This starts a Postgres 15 instance with the credentials expected by the app (see `.env.example` and `docker-compose.yml`).

To stop containers:

```bash
docker compose down
```

### Build and run the app image (optional)

If you want to run the Phoenix app itself inside Docker using `Dockerfile`, you just need to remove the comments in the `docker-compose.yml`

---

## Local development (without Dockerized app)

You can run Phoenix directly on your machine and just use Docker for Postgres (as above) or a local Postgres installation.

### 1. Install dependencies

```bash
mix deps.get
```

### 2. Set up the database

```bash
mix ecto.setup
```

This will:
- Create the database
- Run migrations
- Run seeds (preloads sports & leagues)

Other DB commands:

```bash
mix ecto.migrate      # Run new migrations
mix ecto.reset        # Drop, recreate, migrate, seed
```

### 3. Run the Phoenix server

```bash
mix phx.server
```

The app will be available at:

- `http://localhost:4000`

Alternatively, with IEx:

```bash
iex -S mix phx.server
```

---

## Assets (JS/CSS)

Assets are handled automatically by dev watchers configured in `config/dev.exs`.

Manual commands:

```bash
mix assets.build   # One-shot compile assets
mix assets.deploy  # Minify + digest for prod
```

---

## Tests

Run all tests:

```bash
mix test
```

Run a single test file:

```bash
mix test apps/betting_engine/test/path/to/file_test.exs
```

Run a single test by line:

```bash
mix test apps/betting_engine/test/path/to/file_test.exs:42
```

---

## Odds sync & analysis

The app syncs odds from The Odds API on an interval and pushes updates to LiveViews via PubSub.

### Force a sync manually (from IEx)

Start the server with IEx:

```bash
iex -S mix phx.server
```

Then in the IEx shell:

```elixir
BettingEngine.Sync.Poller.sync_now(force: true)
```

---

## Useful mix commands (summary)

- **Dependencies**
  - `mix deps.get`

- **Database**
  - `mix ecto.setup`
  - `mix ecto.migrate`
  - `mix ecto.reset`

- **Server**
  - `mix phx.server`
  - `iex -S mix phx.server`

- **Routes**
  - `mix phx.routes`

- **Assets**
  - `mix assets.build`
  - `mix assets.deploy`

- **Tests**
  - `mix test`
  - `mix test apps/betting_engine/test/path/to/file_test.exs`
  - `mix test apps/betting_engine/test/path/to/file_test.exs:LINE`

- **Sync**
  - `BettingEngine.Sync.Poller.sync_now(force: true)` (from IEx)

---

## Production notes (high level)

- Build a release and configure `DATABASE_URL`, `SECRET_KEY_BASE`, and `THE_ODDS_API_KEY`.
- Use `mix assets.deploy` before building the release to ensure static assets are digested.
- Point your reverse proxy (e.g. Nginx) at the Phoenix HTTP endpoint (port 4000 by default).