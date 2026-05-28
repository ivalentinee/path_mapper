# Quick Start

This guide walks you through creating a minimal adventure and group, building ZIP files, and running your first session. It assumes the Path Mapper server is already running.

## What is Path Mapper?

Path Mapper is a playback-only VTT. You cannot create or edit content inside the application --- all maps, tokens, and manifests are authored externally, packaged into ZIP files, and loaded by the server. The GM controls the session through a web interface; players see a live-synced view.

## Prerequisites

- **Text editor** --- any editor that can write plain text files
- **GIMP** --- version 2.10 or later ([download](https://www.gimp.org/downloads/)); used to create map images in ORA (OpenRaster) format
- **`zip` command-line tool** --- pre-installed on macOS; on Linux, install via your package manager (e.g. `apt install zip`)
- **Emacs adventurer module** (optional) --- convenience package for editing manifests

## Brief TOML Primer

Path Mapper manifests use [TOML](https://toml.io/en/) --- a configuration file format. Here are the constructs you will encounter:

```toml
# Strings
title = "My Adventure"

# Nested keys
map.file = "map.ora"

# Sections
[section]
key = "value"

# Arrays of tables (repeating sections)
[[scenes]]
name = "Scene 1"

[[scenes]]
name = "Scene 2"

# Inline tables
urls = [
    { name = "Link 1", url = "https://example.com/" }
]
```

For the full specification, see [toml.io](https://toml.io/en/).

## Create a Minimal Group

A group defines the player characters for your session.

### Directory Structure

```
my-group/
  manifest.toml
  player-1.png
```

### manifest.toml

```toml
title = "My Group"

[[players]]
character_name = "Valeros"
player_name = "Alice"
color = "#328546"
token = "player-1.png"
```

The `token` field points to a round PNG image (transparent background recommended).

## Create a Minimal Adventure

An adventure contains one or more scenes, each with a map and optional tokens.

### Directory Structure

```
my-adventure/
  manifest.toml
  map.ora
```

### manifest.toml

```toml
title = "My Adventure"

[[scenes]]
name = "Tavern"
type = "battle"
map.file = "map.ora"
```

### Create the Map in GIMP

1. Open GIMP, create a new image (File > New). Recommended starting size: 1000x1000 pixels.
2. In the Layers panel, double-click the layer name and rename it to `[L1] Background`.
3. Paint or fill the layer with a color (this is your map).
4. Export: File > Export As, choose **OpenRaster (.ora)** format. Save as `map.ora` in your adventure directory.

That is all you need for a minimal map. See the [Maps guide](maps.md) for the full layer naming convention.

## Build ZIPs

Use the build script to package your directories into ZIP files:

```bash
./scripts/build.sh my-adventure/
# produces my-adventure.zip

./scripts/build.sh my-group/
# produces my-group.zip
```

> **WARNING:** The ZIP must contain `manifest.toml` at its root. If the ZIP contains a nested directory (`my-adventure/manifest.toml` instead of `manifest.toml`), Path Mapper will not load it. The build script handles this correctly. If building manually:
>
> ```bash
> cd my-adventure && zip -r ../my-adventure.zip .
> ```
>
> NOT: `zip -r my-adventure.zip my-adventure/`

## Upload and Run

1. Copy the ZIP files to the server's `adventures/` and `groups/` directories.
2. Click **Reload** in the GM panel's Adventures or Groups section to pick up new files (no server restart needed).
3. Open `http://your-server:4000/master` in your browser.
4. Select your adventure from the Adventures panel.
5. Select your group from the Groups panel.
6. Select a scene from the Scenes panel.
7. Open `http://your-server:4000/` in a second tab to see the player view.

## Next Steps

- [Groups](groups.md) --- add classes, extra tokens, and multiple players
- [Maps](maps.md) --- layer groups, map objects, grid configuration
- [Adventures](adventures.md) --- tokens, placement, multiple scenes
- [GM Guide](gm-guide.md) --- session controls, token management

## Reference: Test Fixtures

The repository includes working examples you can copy and modify:

- `test/data/adventures/unpacked/` --- example adventure with two scenes, tokens, and placement
- `test/data/groups/unpacked/` --- example group with two players and extra tokens
