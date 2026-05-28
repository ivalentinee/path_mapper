# Adventures

An adventure is a ZIP file containing a `manifest.toml`, one or more ORA map files, and optional token images and wallpaper.

## Directory Structure

```
my-adventure/
  manifest.toml
  wallpaper.png           (optional)
  map-1.ora
  map-2.ora
  tokens/
    monster-1.png
    npc-1.png
```

## manifest.toml Reference

### Top-Level Fields

| Field       | Type   | Required | Description                                                |
|-------------|--------|----------|------------------------------------------------------------|
| `title`     | string | yes      | Adventure display name                                     |
| `wallpaper` | string | no       | Path to wallpaper image, displayed when no scene is active |
| `urls`      | array  | no       | Reference links displayed in the interface                 |

Each URL entry:

| Field  | Type   | Required | Description       |
|--------|--------|----------|-------------------|
| `name` | string | yes      | Link display name |
| `url`  | string | yes      | URL               |

### Scenes

Scenes are defined with `[[scenes]]` sections. At least one scene is required.

| Field      | Type   | Required | Description                         |
|------------|--------|----------|-------------------------------------|
| `name`     | string | yes      | Scene display name                  |
| `type`     | string | yes      | Must be `"battle"`                  |
| `map.file` | string | yes      | Path to ORA map file within the ZIP |

### Token Definitions

Each scene can define available token types with a `tokens` array:

| Field   | Type    | Required | Description                                                 |
|---------|---------|----------|-------------------------------------------------------------|
| `name`  | string  | yes      | Unique token name (used for placement references)           |
| `size`  | integer | yes      | Token size in grid cells (1 = standard, 2 = large, etc.)    |
| `owner` | string  | yes      | Owner category (case-insensitive), determines default color |
| `image` | string  | yes      | Path to token image within the ZIP                          |
| `color` | string  | no       | Hex color override for the token border                     |

**Owner color defaults:**

| Owner           | Default Color    |
|-----------------|------------------|
| `"enemy"`       | red (#db0909)    |
| `"npc"`         | gray (#a1a1a1)   |
| anything else   | black (#000000)  |

Owner matching is case-insensitive: `"npc"`, `"NPC"`, and `"Npc"` all map to gray.

Use TOML integer syntax for numeric fields (no quotes): `size = 2` not `size = "2"`.

### Token Placement

Each scene can pre-place token instances with a `place_tokens` array:

| Field   | Type    | Required | Description                                                               |
|---------|---------|----------|---------------------------------------------------------------------------|
| `name`  | string  | yes      | Must match a token name from the `tokens` array                           |
| `x`     | integer | yes      | X coordinate in grid units                                                |
| `y`     | integer | yes      | Y coordinate in grid units                                                |
| `state` | string  | no       | Initial state: `"alive"` (default), `"unconscious"`, `"dead"`, `"hidden"` |

The same token name can appear multiple times to place multiple instances. Use TOML integer syntax for coordinates: `x = 10` not `x = "10"`.

**Relationship between `tokens` and `place_tokens`:** `tokens` defines the available token types for a scene. `place_tokens` places specific instances at specific coordinates when the scene loads.

## The "Copy" Button Workflow

The Copy button in the GM's Tokens panel is the bridge between playing and authoring. It serializes the current token positions as a TOML `place_tokens` snippet that you can paste directly into your manifest.

### Step-by-Step

1. Load the adventure and scene in `/master`
2. Add tokens to the scene (from the Tokens panel)
3. Drag tokens to their desired positions on the map
4. Open Tokens panel > Copy tab
5. Click **Copy** --- the TOML snippet is copied to your clipboard
6. Paste the snippet into your adventure's `manifest.toml`, replacing or adding to the scene's `place_tokens` array
7. Rebuild the ZIP and reload

The copied coordinates are in grid units and represent the exact positions as placed in the VTT.

## Complete Example

```toml
title = "Adventure example"

wallpaper = "wallpaper.png"

urls = [
    { name = "Sample URL 1", url = "https://example.net/" },
    { name = "Sample URL 2", url = "https://example.net/" }
]

[[scenes]]
name = "Scene 1"
type = "battle"
map.file = "map.ora"
tokens = [
    { name = "monster 1", size = 2, owner = "enemy", image = "tokens/monster-1.png" },
    { name = "NPC 1", size = 1, owner = "npc", image = "tokens/monster-2.png" }
]
place_tokens = [
    { name = "monster 1", x = 10, y = 20, state = "unconscious" },
    { name = "monster 1", x = 20, y = 25 },
    { name = "NPC 1", x = 50, y = 55 }
]

[[scenes]]
name = "Scene 2"
type = "battle"
map.file = "map-2.ora"
```

## Multiple Scenes

An adventure can contain any number of scenes. Each scene has its own map, tokens, and placement. The GM switches between scenes during a session; scene state is preserved across switches.

## Wallpaper

The `wallpaper` field points to an image displayed when no scene is active. This is typically a title screen or campaign art.
