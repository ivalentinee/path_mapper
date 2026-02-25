# Path Mapper

Move along, nothing to see here

## Build a release (.tar amd64)
```shell
bash ./build_release.sh
```

## Build a release (linux/arm64)
```shell
docker build -t path_mapper --target=dev .
docker run --rm -v $(pwd):/app path_mapper bash -c "MIX_ENV=prod mix do assets.deploy, phx.digest"
docker build -t path_mapper_arm64 . -f Dockerfile.arm64
docker run --rm -v $(pwd):/build --platform=linux/arm64 path_mapper_arm64 bash -c "cp /app/release.tar /build/release.tar"
```

## Required envrironment variables
- `SECRET_KEY_BASE`: get it by asking dev to run `mix phx.gen.secret`
