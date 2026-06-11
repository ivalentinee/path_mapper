# Installation Guide

This guide covers deploying Path Mapper on a server. No Elixir knowledge is required --- the application ships as a self-contained release tarball or Docker image.

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
  -v /path/to/adventures:/app/adventures \
  -v /path/to/groups:/app/groups \
  path_mapper
```

Replace `/path/to/adventures` and `/path/to/groups` with directories containing your ZIP files. See [Quick Start](quick-start.md) for how to create them.

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
    volumes:
      - ./adventures:/app/adventures
      - ./groups:/app/groups
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
mkdir -p /opt/path_mapper/adventures /opt/path_mapper/groups
```

### Run

```bash
export SECRET_KEY_BASE="$(openssl rand -base64 48)"
export PHX_HOST="your-domain.com"
/opt/path_mapper/bin/path_mapper start
```

To run as a daemon, use `start` (backgrounded) or wrap it in a systemd unit:

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
ExecStart=/opt/path_mapper/bin/path_mapper start
ExecStop=/opt/path_mapper/bin/path_mapper stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## Environment Variables

### Required

| Variable          | Description                                                                              |
|-------------------|------------------------------------------------------------------------------------------|
| `SECRET_KEY_BASE` | Session signing key. Generate with `openssl rand -base64 48`. Must be at least 64 bytes. |

### Optional

| Variable                   | Default          | Description                                            |
|----------------------------|------------------|--------------------------------------------------------|
| `PHX_HOST`                 | `example.com`    | Public hostname (used for URL generation)              |
| `PORT`                     | `4000`           | HTTP listen port                                       |
| `ADVENTURE_BASE_PATH`      | `adventures`     | Path to directory containing adventure ZIP files       |
| `GROUP_BASE_PATH`          | `groups`         | Path to directory containing group ZIP files           |
| `CHARKEEPER_SERVER`        | `charkeeper.ru`  | Charkeeper API host for live character stats           |
| `CHARKEEPER_POLL_INTERVAL` | `10000`          | Charkeeper polling interval in milliseconds            |
| `CACERTFILE`               | *(system CAs)*   | Path to a custom CA certificate bundle (PEM format)    |
| `DNS_CLUSTER_QUERY`        | *(none)*         | DNS query for clustering (advanced, multi-node setups) |

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

After deploying, you need adventure and group ZIP files. See the [Quick Start](quick-start.md) guide for creating your first ones, then:

1. Copy `.zip` files into the `adventures/` and `groups/` directories.
2. Open `/master` and click **Reload** in the Adventures or Groups panel to pick up new files (no restart needed).

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

**Adventure/group not appearing after upload** --- Click **Reload** in the GM panel. Files must be `.zip` with `manifest.toml` at the ZIP root (not nested in a subdirectory).

**Charkeeper shows garbled text** --- Ensure the server can reach `charkeeper.ru` (or your custom `CHARKEEPER_SERVER`) over HTTPS. If using a custom CA, set `CACERTFILE`.

**Charkeeper status dot is yellow/red** --- Yellow means some characters failed to fetch; red means all failed. Check that the `charkeeper_id` values are correct UUIDs and that the server has internet access.
