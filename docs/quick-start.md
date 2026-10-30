# Quick Start

This guide walks you through making a map, putting it in front of players, and
running your first session. It assumes the Path Mapper server is already
running.

## What is Path Mapper?

Path Mapper is a playback-only VTT. You cannot create or edit content inside the
application --- maps and tokens are authored externally and uploaded into a
running session by the [client](client.md) on your own machine. The
server holds none of it and forgets everything on restart. The GM controls the session through a web
interface; players see a live-synced view.

A session is a flat set of pieces: **maps, tokens, characters and a wallpaper**.
A map is the playable surface --- there is nothing between a map and what happens
on it. Each piece is a file you hand to the client, one at a time or a directory
at once, in any order.

**Every piece's id comes from its filename**, so the names below are not
decoration. A file with no id in its name is refused.

> There is no package format and there does not need to be one. Pieces upload
> on their own, and a whole session still fits in one file afterwards --- see
> [Writing it down](#writing-it-down) below.

## Prerequisites

- **Text editor** --- any editor that can write plain text files
- **GIMP** --- version 2.10 or later ([download](https://www.gimp.org/downloads/)); used to create map images in ORA (OpenRaster) format

## Brief TOML Primer

The client's own configuration uses [TOML](https://toml.io/en/) --- a
configuration file format. Here are the constructs you will encounter:

```toml
# Strings
wallpaper = "wp0001-0000000001-wallpaper.png"

# Arrays of tables (repeating sections)
[[maps]]
file = "mt0001-0000000001-tavern.ora"
name = "Tavern"

[[maps]]
file = "mt0001-0000000002-cellar.ora"

# Arrays
extra_token_ids = ["tk0002-0000000001", "tk0002-0000000002"]
```

For the full specification, see [toml.io](https://toml.io/en/).

## Make a Map

A map is a `.xcf` or an exported `.ora` renamed `.pmmap`, named for its id:
`mt0001-0000000001-tavern.xcf`.

### Create the Map in GIMP

1. Open GIMP, create a new image (File > New). Recommended starting size: 1000x1000 pixels.
2. In the Layers panel, double-click the layer name and rename it to `[L1] Background`.
3. Paint or fill the layer with a color (this is your map).
4. Save: File > Save As, naming the file `mt0001-0000000001-tavern.xcf` --- the
   id in the name is how the map is identified. The client converts the `.xcf`
   with GIMP when you upload it, so there is no export step.

   Without GIMP on the machine running the client, export instead: File > Export
   As, choose **OpenRaster (.ora)**, and rename the result to `.pmmap`.

That is all you need for a minimal map. See the [Maps guide](maps.md) for the full layer naming convention.

## Upload and Run

Hand the pieces to the [PathMapper client](client.md):

```bash
path-mapper mt0001-0000000001-tavern.xcf tk0001-0000000001-goblin.pmtoken
```

Or a whole directory of them:

```bash
path-mapper ~/campaigns/the-train/*
```

Order does not matter --- each piece carries its own id, and a reference to one
that has not arrived yet resolves when it does. `.pm*` files can also be
double-clicked, once the client's desktop entries are installed.

Then:

1. Open `http://your-server:4000/master` in your browser.
2. Open the left panel and choose **Scenes**, then select your map. Uploading a
   map does not switch the table to it; you do.
3. Open `http://your-server:4000/` in a second tab to see the player view.

The server keeps none of this. A restart leaves an empty board, and the same
command fills it again --- which is also how you pick up an edit: change the
map, upload it again.

## Writing it down

You composed that session by hand. You do not have to do it twice:

```bash
path-mapper save the-train     # writes the-train.pmload
```

A `.pmload` is a **load list** --- a page of TOML naming the pieces and
carrying where everything stood. Next week it is the whole session:

```bash
path-mapper the-train.pmload
```

Because it names the pieces rather than packing them, repainting a map in GIMP
and keeping its id means every list naming that map picks up the new artwork.

For an exact record instead --- the bytes included, so it reopens as it was
however the artwork has changed --- take a **snapshot** from the GM view, or:

```bash
path-mapper snapshot
path-mapper the-train-20261007.pmsnapshot    # later
```

[Preparing a Session](sessions.md) covers both, the file's three keys, and how
a campaign index loads several nights at once.

## Next Steps

- [Maps](maps.md) --- layer groups, map objects, grid configuration
- [Tokens](tokens.md) --- what a PNG may say about itself, and placements
- [GM Guide](gm-guide.md) --- session controls, token management
- [Preparing a Session](sessions.md) --- load lists, snapshots, campaign indexes
- [The Client](client.md) --- making a map mid-session, and where it keeps things

## Reference: Test Fixtures

The repository includes working examples you can copy and modify:

- `test/data/sessions/standard/` --- two maps, two tokens and a wallpaper
- `test/data/sessions/party/` --- the tokens two characters use

These are the project's test fixtures, so they are examples that load. The
characters themselves are declared in `test/support/helpers.ex`, because a
character is four fields and no bytes and has no file of its own.
