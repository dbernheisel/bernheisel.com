## SYSTEM

FROM hexpm/elixir:1.12.2-erlang-24.1.2-ubuntu-focal-20210325 AS builder

ENV LANG=C.UTF-8 \
    LANGUAGE=C:en \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    TERM=xterm \
    MIX_ENV=prod \
    REFRESH_AT=20210105

RUN apt-get update && apt-get install -y \
      git \
      curl

RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs

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
COPY --chown=user:user lib ./lib
COPY --chown=user:user posts ./posts
COPY --chown=user:user priv ./priv
COPY --chown=user:user assets ./assets
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error
RUN mix assets.deploy

CMD ["/bin/bash"]
