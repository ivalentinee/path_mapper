# Path Mapper

Lightweight, playback-only VTT (Virtual Tabletop) for Pathfinder 2e and other square-grid TTRPGs. Built with Elixir/Phoenix LiveView. No database, and no content of its own: everything is in memory, and a session is fed to the running server from the game master's own machine.

- `/master` --- Game Master interface
- `/` --- Player view

PathMapper is a player rather than a composer. Maps, tokens and characters are made
in the tools you already use --- GIMP, Emacs, a text editor --- and PathMapper only
plays them. That is why there is no built-in editor and nothing stored on the
server: the [PathMapper client](docs/client.md) sends a session over when you
want one, and the server forgets it on restart.

A session is a flat set of pieces --- maps, tokens, characters and a wallpaper. A
map is the playable surface. Nothing gathers them: you hand the client a
directory, and write the result down afterwards as a load list or a snapshot.

## Documentation

Everything is in [docs/](docs/README.md):

- [Quick Start](docs/quick-start.md) --- make a map and run a session
- [The Client](docs/client.md) --- the program that feeds the server
- [Preparing a Session](docs/sessions.md) --- load lists, snapshots, campaign indexes
- [Maps](docs/maps.md), [Tokens](docs/tokens.md), [Characters](docs/characters.md) --- authoring content
- [GM Guide](docs/gm-guide.md) --- running the table
- [Installation](docs/installation.md) --- deploying the server

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
| `API_TOKEN`                | prod     | ---              | Bearer token every command needs           |
| `CHARKEEPER_SERVER`        | no       | `charkeeper.ru`  | Charkeeper API host                        |
| `CHARKEEPER_POLL_INTERVAL` | no       | `10000`          | Charkeeper poll interval (ms)              |

See [Installation Guide](docs/installation.md) for the full list and deployment details.
