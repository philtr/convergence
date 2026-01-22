FROM hexpm/elixir:1.19.4-erlang-28.3.1-debian-trixie-20260112-slim AS build

RUN apt-get update && apt-get install -y build-essential git && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only prod
RUN mix deps.compile

COPY lib lib
COPY priv priv

RUN mix compile
RUN mix release

FROM debian:bookworm-slim AS app

RUN apt-get update && apt-get install -y libstdc++6 libncurses6 openssl ca-certificates curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN useradd --system --create-home --home-dir /app app

USER app

ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV PORT=4000

COPY --from=build /app/_build/prod/rel/convergence ./

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD curl -f http://localhost:4000/healthz || exit 1

CMD ["bin/convergence", "start"]
