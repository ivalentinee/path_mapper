# Installation Guide

This guide covers deploying Path Mapper on a server. No Elixir knowledge is required --- the application ships as a self-contained release tarball or Docker image.

The server holds nothing of its own. There are no adventure or group directories to
populate and nothing to copy over when content changes: a session is fed to the
running server by the [PathMapper client](../client/README.md) on your own machine,
and the server forgets all of it when it restarts. What you deploy here is an empty
board that a client fills.

## Deployment Options

- **Docker** (recommended) --- single container, no runtime dependencies
- **Release tarball** --- extract and run; requires only a Linux host

## Option 1: Docker

### Build the image

```bash
git clone <repo-url> path_mapper && cd path_mapper
docker build -t path_mapper --target=release .
```

### Run

```bash
docker run -d \
  --name path_mapper \
  -p 4000:4000 \
  -e SECRET_KEY_BASE="$(openssl rand -base64 48)" \
  -e PHX_HOST="your-domain.com" \
  -e API_TOKEN="$(openssl rand -hex 32)" \
  path_mapper
```

No volumes: the server stores nothing that should outlive the container. Keep the
`API_TOKEN` --- the client needs the same value, and without one every API route
refuses, which leaves you with a board nothing can fill.

### docker-compose

Create a `docker-compose.yaml`:

```yaml
version: "3"
services:
  web:
    build:
      context: .
      target: release
    ports:
      - "4000:4000"
    environment:
      SECRET_KEY_BASE: "generate-with-openssl-rand-base64-48"
      PHX_HOST: "your-domain.com"
      API_TOKEN: "generate-with-openssl-rand-hex-32"
    restart: unless-stopped
```

Then:

```bash
docker-compose up -d
```

## Option 2: Release Tarball

### Prerequisites

The build machine needs Elixir 1.19+ and Erlang/OTP 28+. The target server needs only a compatible Linux environment (glibc).

### Build

```bash
git clone <repo-url> path_mapper && cd path_mapper
bash build_release.sh
```

This produces `release.tar`.

### Deploy

On the target server:

```bash
mkdir -p /opt/path_mapper
tar -xf release.tar -C /opt/path_mapper
```

### Run

```bash
export SECRET_KEY_BASE="$(openssl rand -base64 48)"
export PHX_HOST="your-domain.com"
export API_TOKEN="$(openssl rand -hex 32)"
/opt/path_mapper/bin/path_mapper start
```

To run as a daemon, use `daemon` (backgrounded) or wrap it in a systemd unit:

```ini
[Unit]
Description=Path Mapper VTT
After=network.target

[Service]
Type=exec
User=pathm
WorkingDirectory=/opt/path_mapper
Environment=SECRET_KEY_BASE=your-secret-key
Environment=PHX_HOST=your-domain.com
Environment=API_TOKEN=your-api-token
ExecStart=/opt/path_mapper/bin/path_mapper start
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

There is no `ExecStop`: the release runs with Erlang distribution disabled, so the
commands that reach a running node over it --- `remote`, `rpc`, `pid`, `restart`
and `stop` --- are unavailable. systemd's SIGTERM stops the VM cleanly, and
PathMapper holds nothing that a restart loses. Distribution is off because one
instance clusters with nothing, and leaving it on starts epmd listening on port
4369 for no one.

## Environment Variables

### Required

| Variable          | Description                                                                              |
|-------------------|------------------------------------------------------------------------------------------|
| `SECRET_KEY_BASE` | Session signing key. Generate with `openssl rand -base64 48`. Must be at least 64 bytes. |
| `API_TOKEN`       | Shared secret the client authenticates with. Generate with `openssl rand -hex 32`. Without it every API route refuses, so nothing can be uploaded. |

### Optional

| Variable                   | Default          | Description                                            |
|----------------------------|------------------|--------------------------------------------------------|
| `PHX_HOST`                 | `example.com`    | Public hostname (used for URL generation)              |
| `PORT`                     | `4000`           | HTTP listen port                                       |
| `CHARKEEPER_SERVER`        | `charkeeper.ru`  | Charkeeper API host for live character stats           |
| `CHARKEEPER_POLL_INTERVAL` | `10000`          | Charkeeper polling interval in milliseconds            |
| `CACERTFILE`               | *(system CAs)*   | Path to a custom CA certificate bundle (PEM format)    |

## Upload size

A client sends one asset per request, so requests stay small however large an
adventure is --- the biggest single thing that crosses the wire is one map image.
If your reverse proxy caps request bodies, a limit of around 50 MB is comfortable.

## Reverse Proxy

Path Mapper uses WebSockets for live updates. Your reverse proxy must support WebSocket upgrade.

### nginx

```nginx
upstream path_mapper {
    server 127.0.0.1:4000;
}

server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate     /etc/ssl/certs/your-cert.pem;
    ssl_certificate_key /etc/ssl/private/your-key.pem;

    location / {
        proxy_pass http://path_mapper;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Caddy

```
your-domain.com {
    reverse_proxy localhost:4000
}
```

Caddy handles WebSocket upgrade and TLS automatically.

## Web Endpoints

| URL       | Purpose                |
|-----------|------------------------|
| `/master` | Game Master interface  |
| `/`       | Player view            |

Both open in a regular browser --- no client install needed. Share the player URL with your group.

## Content Setup

Content never reaches the server as files. Install the
[PathMapper client](../client/README.md) on the machine your adventures live on,
point its config at this server, and feed a session from there:

```toml
# ~/.config/pathmapper/config.toml
server = "https://your-domain.com"
token = "the API_TOKEN you set above"
snapshots = "~/snapshots"
```

```bash
path-mapper my-adventure.pmadventure my-group.pmgroup
```

See the [Quick Start](quick-start.md) guide for creating your first adventure.

## Charkeeper Integration

If your players use [Charkeeper](https://charkeeper.ru/) for character sheets, Path Mapper can pull live stats (HP, AC, class, ancestry) automatically.

To enable: add `charkeeper_id` to each player in the group manifest:

```toml
[[players]]
character_name = "Valeros"
player_name = "Alice"
color = "#328546"
token = "player-1.png"
charkeeper_id = "uuid-from-charkeeper-url"
```

The UUID is the last segment of the character's Charkeeper URL (e.g., `https://charkeeper.ru/characters/abc-123-def` --- the ID is `abc-123-def`).

Stats are polled every 10 seconds by default. Adjust with `CHARKEEPER_POLL_INTERVAL`.

## Troubleshooting

**"environment variable SECRET_KEY_BASE is missing"** --- Set the `SECRET_KEY_BASE` environment variable. Generate one with `openssl rand -base64 48`.

**WebSocket connection fails behind proxy** --- Make sure your reverse proxy passes `Upgrade` and `Connection` headers. See the nginx example above.

**Every upload is refused with 401** --- The server has no `API_TOKEN`, or the
client's differs. An unset token refuses everything by design: a server that would
accept anything is worse than one that accepts nothing.

**An upload is refused naming a missing manifest** --- A `.pmadventure` must be a
ZIP with `manifest.toml` at its root, not nested in a subdirectory.

**The board is empty after a restart** --- Expected. The server keeps nothing
between runs; upload the session again, or restore a snapshot with
`path-mapper my-session.pmsnapshot`.

**Charkeeper shows garbled text** --- Ensure the server can reach `charkeeper.ru` (or your custom `CHARKEEPER_SERVER`) over HTTPS. If using a custom CA, set `CACERTFILE`.

**Charkeeper status dot is yellow/red** --- Yellow means some characters failed to fetch; red means all failed. Check that the `charkeeper_id` values are correct UUIDs and that the server has internet access.
