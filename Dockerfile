## SYSTEM

FROM hexpm/elixir:1.11.3-erlang-23.2.4-ubuntu-focal-20201008 AS builder

ENV LANG=C.UTF-8 \
    LANGUAGE=C:en \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    TERM=xterm \
    MIX_ENV=prod \
    REFRESH_AT=20210105

RUN apt-get update && apt-get install -y \
      git \
      nodejs

ARG USER_ID
ARG GROUP_ID

RUN groupadd -o --gid $GROUP_ID user && \
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
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error
RUN mix assets.deploy

## APP
FROM builder AS app
USER user
COPY --from=frontend --chown=user:user /home/user/app/priv/static ./priv/static
COPY --chown=user:user lib ./lib
COPY --chown=user:user posts ./posts

CMD ["/bin/bash"]
