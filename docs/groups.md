# Groups

A group defines the player characters for a game session: a ZIP file with a
`manifest.toml` and player token images. You build it outside PathMapper and hand
it to the [client](../client/README.md), which uploads it into a running session.

A group and an adventure are independent. Either can be replaced without the
other, so swapping the party mid-campaign is uploading a new group.

## Directory Structure

```
tg0001-0000000001-my-group/
  manifest.toml
  player-1/
    tk0002-0000000004-player-1.png
    tk0002-0000000001-some-marker.png
  player-2/
    player-2.png
```

Subdirectories are optional --- you can place all images at the root. They help
when players have several tokens.

Zip the contents and name the ZIP with the group's id:
`tg0001-0000000001-my-group.pmgroup`.

**Token filenames carry their ids**, the same as in an adventure --- see
[Adventures](adventures.md#identity-every-id-comes-from-a-filename) for the
format and why ids are global. A player's own id goes in the manifest.

## manifest.toml Reference

### Top-Level Fields

| Field   | Type   | Required | Description        |
|---------|--------|----------|--------------------|
| `title` | string | yes      | Group display name |

### Players

Each player is defined with a `[[players]]` section:

| Field            | Type   | Required | Description                                              |
|------------------|--------|----------|----------------------------------------------------------|
| `id`             | string | yes      | The player's id, in the id format                        |
| `character_name` | string | yes      | In-game character name, used as the token label          |
| `player_name`    | string | yes      | Real player name                                         |
| `color`          | string | yes      | Hex color code (e.g. `"#328546"`), used for token border |
| `class`          | string | no       | Character class, displayed in the group overview panel   |
| `token`          | string | yes      | Path to token image within the ZIP                       |
| `extra_tokens`   | array  | no       | Markings this player may put on the board                |
| `charkeeper_id`  | string | no       | Character id on Charkeeper, for live stats               |

A player's **own token** goes on the board once: asking twice leaves the one
already there. **Extra tokens are markings** --- traps, objects, anything a player
puts down --- and each request places another, so a player may have several at
once.

The player's `id` is what owns their token, their drawings and their initiative
entry. It is not their character name, which they may change.

Each extra token has:

| Field   | Type   | Required | Description                              |
|---------|--------|----------|------------------------------------------|
| `name`  | string | yes      | Display name for the extra token         |
| `image` | string | yes      | Path to extra token image within the ZIP |

## Complete Example

```toml
title = "Test group"

[[players]]
id = "pg0001-0000000001"
character_name = "Character 1"
player_name = "Player 1"
color = "#328546"
class = "Fighter"
token = "player-1/tk0002-0000000004-player-1.png"
extra_tokens = [
    { image = "player-1/tk0002-0000000001-some-marker.png", name = "Some marker" },
    { image = "player-1/tk0002-0000000002-some-marker-2.png", name = "Some marker 2" }
]

[[players]]
id = "pg0001-0000000002"
character_name = "Character 2"
player_name = "Player 2"
color = "#8100fa"
token = "player-2/tk0002-0000000005-player-2.png"
extra_tokens = [
    { image = "player-2/tk0002-0000000003-some-marker.png", name = "Some marker" }
]
```

This is the test fixture, so it is an example that loads.

## Getting it into a session

```sh
path-mapper tg0001-0000000001-my-group.pmgroup
```

Or double-click it. Uploading a group over a running session replaces what it
declares and leaves everything else alone.

Each player claims their character themselves, from the Group panel in the player
view --- the GM does not assign them.

## Token Image Recommendations

- **Format:** PNG with transparent background
- **Shape:** Round (the application renders tokens as circles)
- **Size:** 200-400 pixels per side is a good balance between quality and file size
