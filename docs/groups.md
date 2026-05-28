# Groups

A group defines the player characters for a game session. It is a ZIP file containing a `manifest.toml` and player token images.

## Directory Structure

```
my-group/
  manifest.toml
  player-1/
    player-1.png
    some-marker.png
  player-2/
    player-2.png
```

Subdirectories are optional --- you can place all images at the root. Subdirectories help organize when players have multiple tokens.

## manifest.toml Reference

### Top-Level Fields

| Field   | Type   | Required | Description        |
|---------|--------|----------|--------------------|
| `title` | string | yes      | Group display name |

### Players

Each player is defined with a `[[players]]` section:

| Field            | Type   | Required | Description                                              |
|------------------|--------|----------|----------------------------------------------------------|
| `character_name` | string | yes      | In-game character name, used as the token label          |
| `player_name`    | string | yes      | Real player name                                         |
| `color`          | string | yes      | Hex color code (e.g. `"#328546"`), used for token border |
| `class`          | string | no       | Character class, displayed in the group overview panel   |
| `token`          | string | yes      | Path to token image within the ZIP                       |
| `extra_tokens`   | array  | no       | Additional markers/tokens for this player                |

Each extra token has:

| Field   | Type   | Required | Description                              |
|---------|--------|----------|------------------------------------------|
| `name`  | string | yes      | Display name for the extra token         |
| `image` | string | yes      | Path to extra token image within the ZIP |

## Complete Example

```toml
title = "Test group"

[[players]]
character_name = "Character 1"
player_name = "Player 1"
color = "#328546"
class = "Fighter"
token = "player-1/player-1.png"
extra_tokens = [
    { image = "player-1/some-marker.png", name = "Some marker" },
    { image = "player-1/some-marker-2.png", name = "Some marker 2" }
]

[[players]]
character_name = "Character 2"
player_name = "Player 2"
color = "#8100fa"
token = "player-2/player-2.png"
extra_tokens = [
    { image = "player-2/some-marker.png", name = "Some marker" }
]
```

## Token Image Recommendations

- **Format:** PNG with transparent background
- **Shape:** Round (the application renders tokens as circles)
- **Size:** 200-400 pixels per side is a good balance between quality and file size
