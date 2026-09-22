# Quick Start

This guide walks you through creating a minimal adventure and group, building ZIP files, and running your first session. It assumes the Path Mapper server is already running.

## What is Path Mapper?

Path Mapper is a playback-only VTT. You cannot create or edit content inside the
application --- maps, tokens and manifests are authored externally, packaged into
ZIP files, and uploaded into a running session by the
[client](../client/README.md) on your own machine. The server holds none of it
and forgets everything on restart. The GM controls the session through a web
interface; players see a live-synced view.

**Every asset's id comes from its filename**, so the names below are not
decoration --- see [Adventures](adventures.md#identity-every-id-comes-from-a-filename).

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
tg0001-0000000001-my-group/
  manifest.toml
  tk0002-0000000001-valeros.png
```

### manifest.toml

```toml
title = "My Group"

[[players]]
id = "pg0001-0000000001"
character_name = "Valeros"
player_name = "Alice"
color = "#328546"
token = "tk0002-0000000001-valeros.png"
```

The `token` field points to a round PNG image (transparent background recommended).

## Create a Minimal Adventure

An adventure contains one or more scenes, each with a map and optional tokens.

### Directory Structure

```
tt0001-0000000001-my-adventure/
  manifest.toml
  mt0001-0000000001-tavern.ora
```

### manifest.toml

```toml
title = "My Adventure"

[[scenes]]
id = "st0001-0000000001"
name = "Tavern"
type = "battle"
map.file = "mt0001-0000000001-tavern.ora"
```

### Create the Map in GIMP

1. Open GIMP, create a new image (File > New). Recommended starting size: 1000x1000 pixels.
2. In the Layers panel, double-click the layer name and rename it to `[L1] Background`.
3. Paint or fill the layer with a color (this is your map).
4. Export: File > Export As, choose **OpenRaster (.ora)** format. Save as
   `mt0001-0000000001-tavern.ora` in your adventure directory --- the id in the
   name is how the map is identified.

That is all you need for a minimal map. See the [Maps guide](maps.md) for the full layer naming convention.

## Build ZIPs

Use the build script to package your directories into ZIP files:

```bash
./scripts/build.sh tt0001-0000000001-my-adventure/
./scripts/build.sh tg0001-0000000001-my-group/
```

> **WARNING:** The ZIP must contain `manifest.toml` at its root. If the ZIP contains a nested directory (`my-adventure/manifest.toml` instead of `manifest.toml`), Path Mapper will not load it. The build script handles this correctly. If building manually:
>
> ```bash
> cd tt0001-0000000001-my-adventure && zip -r ../tt0001-0000000001-my-adventure.zip .
> ```
>
> NOT: `zip -r out.zip tt0001-0000000001-my-adventure/`

## Upload and Run

Rename the ZIPs so their extension says what they are --- `.pmadventure` and
`.pmgroup` --- and open them with the [PathMapper client](../client/README.md):

```bash
path-mapper tt0001-0000000001-my-adventure.pmadventure tg0001-0000000001-my-group.pmgroup
```

Or double-click them, once the client's desktop entries are installed. Either way
the client unpacks them, uploads what they contain, and tells the server what to
make of it. Nothing is copied to the server and nothing has to be reloaded.

Then:

1. Open `http://your-server:4000/master` in your browser.
2. Select a scene from the Scenes panel.
3. Open `http://your-server:4000/` in a second tab to see the player view.

The server keeps none of this. A restart leaves an empty board, and the same
command fills it again --- which is also how you pick up an edit: change the
adventure, upload it again.

## Next Steps

- [Groups](groups.md) --- add classes, extra tokens, and multiple players
- [Maps](maps.md) --- layer groups, map objects, grid configuration
- [Tokens](tokens.md) --- what a PNG may say about itself, and placements
- [Adventures](adventures.md) --- tokens, placement, multiple scenes
- [GM Guide](gm-guide.md) --- session controls, token management

## Reference: Test Fixtures

The repository includes working examples you can copy and modify:

- `test/data/adventures/unpacked/` --- an adventure with two scenes, tokens and
  placement
- `test/data/groups/unpacked/` --- a group with two players and extra tokens

These are the project's test fixtures, so they are examples that load.
