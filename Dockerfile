## SYSTEM

FROM hexpm/elixir:1.10.3-erlang-23.0.3-ubuntu-focal-20200703 AS builder

ENV LANG=C.UTF-8 \
    LANGUAGE=C:en \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    TERM=xterm \
    MIX_ENV=prod \
    REFRESH_AT=20210105

RUN apt-get update && apt-get install -y \
      git

ARG USER_ID
ARG GROUP_ID

RUN groupadd --gid $GROUP_ID user && \
    useradd -m --gid $GROUP_ID --uid $USER_ID user

USER user
RUN mkdir /home/user/app
WORKDIR /home/user/app

RUN mix local.rebar --force && \
    mix local.hex --if-missing --force

COPY --chown=user:user mix.* ./
COPY --chown=user:user config ./config
COPY --chown=user:user VERSION .
RUN mix do deps.get, deps.compile

## FRONTEND

FROM node:12.18.3-alpine AS frontend

RUN mkdir -p /home/user/app
WORKDIR /home/user/app
# PurgeCSS needs to see the Elixir stuff
COPY lib ./lib
COPY assets/package.json assets/package-lock.json ./assets/
COPY --from=builder /home/user/app/deps/phoenix ./deps/phoenix
COPY --from=builder /home/user/app/deps/phoenix_html ./deps/phoenix_html
COPY --from=builder /home/user/app/deps/phoenix_live_view ./deps/phoenix_live_view
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

COPY assets ./assets
RUN npm --prefix ./assets run deploy

## APP
FROM builder AS app
USER user
COPY --from=frontend --chown=user:user /home/user/app/priv/static ./priv/static
COPY --chown=user:user lib ./lib
COPY --chown=user:user posts ./posts
RUN mix phx.digest

CMD ["/bin/bash"]
