# BUILD LAYER

FROM hexpm/elixir:1.16.1-erlang-26.2.2-alpine-3.18.6 AS build
RUN apk add --no-cache build-base npm gcompat
WORKDIR /app

## HEX
ENV HEX_HTTP_TIMEOUT=20
RUN mix local.hex --if-missing --force && \
    mix local.rebar
ENV MIX_ENV=prod
ENV SECRET_KEY_BASE=nokeyyet

## COMPILE
COPY mix.exs mix.lock ./
COPY config/config.exs ./config/config.exs
COPY VERSION .
COPY config/prod.exs ./config/prod.exs
RUN mix deps.get --only prod
RUN mix do tailwind.install, esbuild.install
RUN mix deps.compile

## BUILD RELEASE
COPY assets ./assets
COPY lib ./lib
COPY rel ./rel
COPY posts ./posts
COPY priv ./priv
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error
RUN mix assets.deploy
COPY config/runtime.exs ./config/runtime.exs
RUN mix release

# APP LAYER

FROM alpine:3.18.6 AS app
RUN apk add --no-cache libstdc++ openssl ncurses-libs
WORKDIR /app
RUN chown nobody:nobody /app
USER nobody:nobody

## COPY RELEASE
COPY --from=build --chown=nobody:nobody app/_build/prod/rel/bern ./
ENV HOME=/app
ENV MIX_ENV=prod
ENV SECRET_KEY_BASE=nokeyyet
ENV PORT=4000

CMD ["bin/bern", "start"]
