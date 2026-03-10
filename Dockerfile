FROM hexpm/elixir:1.16.3-erlang-26.2.5-alpine-3.19.0 AS build

RUN apk add --no-cache build-base git nodejs npm

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY apps/betting_engine/mix.exs apps/betting_engine/
COPY apps/betting_web/mix.exs apps/betting_web/
RUN mix deps.get --only prod
RUN mix deps.compile

COPY config config/
COPY apps apps/
RUN mix compile

RUN mix assets.deploy

RUN mix release

FROM alpine:3.19 AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

COPY --from=build /app/_build/prod/rel/betting_umbrella ./

ENV HOME=/app
ENV MIX_ENV=prod
ENV PORT=4000

EXPOSE 4000

CMD ["/app/bin/betting_umbrella", "start"]
