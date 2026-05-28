FROM elixir:1.19.5-slim AS dev

EXPOSE 4000

RUN apt-get update && \
    apt-get install -y apt-utils openssl ca-certificates inotify-tools build-essential locales zip unzip git && \
    locale-gen && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    apt-get clean

ENV LANG="en_US.UTF-8" LANGUAGE="en_US:en" LC_ALL="en_US.UTF-8"

RUN mix local.hex --force && mix local.rebar --force

COPY ./docker/setup-dev-user.sh /tmp/setup-dev-user.sh
RUN bash /tmp/setup-dev-user.sh

RUN mkdir /app
WORKDIR /app

CMD ["mix", "phx.server"]

## Build release
FROM dev AS build-release

COPY . /app

ARG RELEASE_NAME=path_mapper
ENV MIX_ENV=prod RELEASE_NAME=${RELEASE_NAME}

RUN mix deps.get && mix deps.compile
RUN mix compile
RUN mix assets.deploy && mix phx.digest
RUN mix release $RELEASE_NAME
RUN tar -C "./_build/prod/rel/${RELEASE_NAME}" -cf release.tar ./

## Release
FROM elixir:1.19.5-slim AS release

RUN mkdir /app
WORKDIR /app

COPY --from=build-release /app/release.tar /app/release.tar

RUN tar -xf release.tar

CMD ["/app/bin/path_mapper", "start"]
