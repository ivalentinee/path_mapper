# Path Mapper

Lightweight, playback-only VTT (Virtual Tabletop) for Pathfinder 2e and other square-grid TTRPGs. Built with Elixir/Phoenix LiveView. No database --- all state is in-memory via OTP, with content loaded from ZIP files.

- `/master` --- Game Master interface
- `/` --- Player view

## Documentation

See the [docs/](docs/) folder for content authoring guides (adventures, groups, maps) and the [Installation Guide](docs/installation.md) for server deployment.

## Development

### Prerequisites

- Elixir 1.19+ / Erlang OTP 28+
- Node.js (for asset building via esbuild)

Or use Docker (no local Elixir needed):

```bash
docker-compose up
# Server at http://localhost:4000
```

### Local Setup

```bash
mix setup          # Install deps + build assets
mix phx.server     # Dev server at http://localhost:4000
```

### Quality Checks

```bash
mix test           # Run tests
mix format         # Auto-format code
mix credo          # Lint (strict mode)
mix paranoid       # All three: test + format check + credo
```

`mix paranoid` is the quality gate --- all checks must pass before committing.

### Build a Release

```bash
# Tarball (current architecture)
bash build_release.sh    # Produces release.tar

# Docker
docker build -t path_mapper --target=release .
```

### Environment Variables

| Variable                   | Required | Default          | Description                                |
|----------------------------|----------|------------------|--------------------------------------------|
| `SECRET_KEY_BASE`          | prod     | ---              | Session signing key (`mix phx.gen.secret`) |
| `PHX_HOST`                 | no       | `example.com`    | Public hostname                            |
| `PORT`                     | no       | `4000`           | HTTP port                                  |
| `ADVENTURE_BASE_PATH`      | no       | `adventures`     | Path to adventure ZIPs                     |
| `GROUP_BASE_PATH`          | no       | `groups`         | Path to group ZIPs                         |
| `CHARKEEPER_SERVER`        | no       | `charkeeper.ru`  | Charkeeper API host                        |
| `CHARKEEPER_POLL_INTERVAL` | no       | `10000`          | Charkeeper poll interval (ms)              |

See [Installation Guide](docs/installation.md) for the full list and deployment details.
