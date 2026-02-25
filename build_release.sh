export MIX_ENV=prod
export RELEASE_NAME=path_mapper

mix deps.get && \
    mix deps.compile && \
    mix compile && \
    mix assets.deploy && \
    mix phx.digest && \
    mix release ${RELEASE_NAME} --overwrite && \
    tar -C "./_build/prod/rel/${RELEASE_NAME}" -cf release.tar ./
