# Adventures

An adventure is a ZIP file: a `manifest.toml`, one or more ORA map files, and
optional token images and wallpaper. You build it outside PathMapper and hand it
to the [client](../client/README.md), which uploads what it contains.

The server keeps none of it. It holds what a client has given it and forgets all
of it when it restarts, so an adventure is something you load rather than
something you install.

## Identity: every id comes from a filename

PathMapper reads the id of a map or a token from its **filename**, and the id of
an adventure from the name of its ZIP. An asset without one cannot be placed.

```
tk0001-0000000042-monster-1.png
└──────┬────────┘ └────┬─────┘
       id         what it is, for you
```

The id is two letters, four digits, a dash, and ten digits:
`[a-z]{2}[0-9]{4}-[0-9]{10}`. The letters are yours to choose — `tk` for tokens
and `mt` for maps read well — and nothing enforces their meaning.

**Ids are global.** Not per adventure, not per campaign. If the same token
appears in two adventures it has one id, and re-declaring it is a harmless
replace rather than a collision. That is what lets a player's token from one
campaign be an NPC in another: it is the same token.

Scenes and players carry their ids in the manifest instead, since neither is a
file.

## Directory structure

```
tt0001-0000000001-my-adventure/
  manifest.toml
  wallpaper.png                         (optional)
  mt0001-0000000001-cave.ora
  mt0001-0000000002-tavern.ora
  tokens/
    tk0001-0000000001-goblin.png
    tk0001-0000000002-innkeeper.png
```

Zip the *contents*, and name the ZIP with the adventure's id:
`tt0001-0000000001-my-adventure.pmadventure`. The `.pmadventure` extension is
what tells the client what it is — see [the client](../client/README.md).

Files the manifest does not name are never uploaded, so a `.xcf` beside the
`.ora` it was exported from costs nothing.

## manifest.toml reference

### Top level

| Field       | Type   | Required | Description                                                |
|-------------|--------|----------|------------------------------------------------------------|
| `title`     | string | yes      | Adventure display name                                     |
| `wallpaper` | string | no       | Path to wallpaper image, shown when no scene is active     |
| `urls`      | array  | no       | Reference links shown in the interface                     |

Each URL entry takes `name` and `url`, both strings.

### Scenes

`[[scenes]]` sections. At least one is required.

| Field      | Type   | Required | Description                         |
|------------|--------|----------|-------------------------------------|
| `id`       | string | yes      | The scene's id, in the id format    |
| `name`     | string | yes      | Scene display name                  |
| `type`     | string | yes      | Must be `"battle"`                  |
| `map.file` | string | yes      | Path to the ORA map within the ZIP  |

### Tokens a scene may place

The `tokens` array declares what the scene can put on the board. The id comes
from the image's filename, so it is not written again here.

| Field   | Type    | Required | Description                                              |
|---------|---------|----------|----------------------------------------------------------|
| `image` | string  | yes      | Path to the token image within the ZIP                   |
| `name`  | string  | yes      | What the token is called                                 |
| `size`  | integer | yes      | Size in grid cells: 1 is standard, 2 is large            |
| `owner` | string  | yes      | `enemy`, `npc`, `none`, or a player id from the group    |

Owner decides the border colour: `enemy` red, `npc` grey, a player their own.
Matching is case-insensitive.

Use TOML numbers, not strings: `size = 2`, never `size = "2"`.

### Tokens the scene starts with

The `place_tokens` array puts tokens on the board when the scene loads. Each
entry is one **placement** — a token on a map — and has an identity of its own.

| Field     | Type   | Required | Description                                                   |
|-----------|--------|----------|----------------------------------------------------------------|
| `game_id` | string | yes      | Names this placement; see below                               |
| `x`, `y`  | number | yes      | Position in **grid cells**                                     |
| `state`   | string | no       | `alive` (default), `unconscious`, `dead`, `hidden`            |
| `owner`   | string | no       | Defaults to the token's own owner                             |
| `name`    | string | no       | Defaults to the token's own name                              |

**`game_id` is `<token-id>-<anything>`.** The prefix says which token is placed;
the suffix is yours and names *this* placement:

```toml
{ game_id = "tk0001-0000000001-left-guard",  x = 3, y = 7 },
{ game_id = "tk0001-0000000001-right-guard", x = 5, y = 7 }
```

Two placements of one goblin, each nameable and each addressable on its own. Two
entries may not share a `game_id` within a scene — the second is dismissed, the
first stands, and the upload warns you which was dropped.

**Coordinates are grid cells, not pixels.** `x = 3` is the fourth column. A token
off the grid takes a fraction: `x = 15.1` is cell 15 and a tenth. Cells mean the
same place after a map is re-exported at another size, which pixels did not.

**`name` is per placement.** Four goblins from one token are four of the same
name otherwise; a name here is how "the crooked-ear one" gets written down. The
GM can also set it during play, from the Tokens panel.

## Getting it into a session

```sh
path-mapper tt0001-0000000001-my-adventure.pmadventure
```

Or double-click it, once the client's desktop entries are installed. The client
unpacks the ZIP, uploads each asset the manifest names, and declares the
adventure, its scenes, its maps and its tokens. Nothing is copied to the server's
disk beforehand, and there is nothing to restart.

Uploading an adventure over a running session **replaces what it declares and
leaves the rest** — so fixing a token image mid-session is re-uploading the
adventure, not reloading the game.

Removing one thing rather than replacing it is a server command the client does
not yet wrap:

```sh
curl -X DELETE -H "Authorization: Bearer $API_TOKEN" \
  https://your-server/api/entities/tk0001-0000000042
```

In practice you rarely need it: uploading a corrected adventure replaces what it
declares, and `path-mapper reset` empties the board entirely.

## The Copy button

The Copy button in the GM's Tokens panel is the bridge from playing back to
authoring. It writes the current arrangement as a `place_tokens` array you paste
into the scene in your `manifest.toml`.

1. Load the adventure and select the scene
2. Arrange tokens on the map
3. Tokens panel → **COPY**
4. Paste over that scene's `place_tokens`
5. Rebuild the ZIP and upload it again

What it writes is what the loader reads, field for field — including any names
and owners you changed during play.

## Complete example

```toml
title = "Adventure example"
wallpaper = "wallpaper.png"

urls = [
    { name = "Sample URL 1", url = "https://example.net/" }
]

[[scenes]]
id = "st0001-0000000001"
name = "Scene 1"
type = "battle"
map.file = "mt0001-0000000001-map.ora"
tokens = [
    { name = "monster 1", size = 2, owner = "enemy", image = "tokens/tk0001-0000000001-monster-1.png" },
    { name = "NPC 1", size = 1, owner = "npc", image = "tokens/tk0001-0000000002-monster-2.png" }
]
place_tokens = [
    { game_id = "tk0001-0000000001-fallen", x = 1, y = 2, state = "unconscious" },
    { game_id = "tk0001-0000000001-standing", x = 2, y = 2.5 },
    { game_id = "tk0001-0000000002-lone", x = 5, y = 5.5 }
]

[[scenes]]
id = "st0001-0000000002"
name = "Scene 2"
type = "battle"
map.file = "mt0001-0000000001-map.ora"
```

This is the test fixture, so it is an example that loads.

## Multiple scenes

An adventure may hold any number. The GM switches between them during a session
and each keeps its own state — where tokens stand, what has been drawn — across
switches.
