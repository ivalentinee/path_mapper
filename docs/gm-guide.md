# GM Session Guide

This guide covers running a game session using the GM interface.

## Accessing the GM View

Open `http://your-server:4000/master` in your browser.

## Interface Overview

- **Left panel** (GM-only): Game, Scenes, Map, Tokens, Initiative
- **Right panel** (shared with players): Group overview, Snap-to-grid toggle
- **Scene indicator** (top): shows current scene name, click to open scene selector
- **Wallpaper**: displayed when no scene is active

## Session Workflow

1. Upload an adventure and a group with the
   [client](../client/README.md) --- there is nothing to select here, since the
   console issues no commands
2. Open left panel > **Scenes** > select a scene
3. Add player tokens: Tokens panel > Players > "Add All" or individually
4. Play the session

To change what the session holds mid-game --- a new map, a fixed token image, a
different group --- upload it again. What is re-declared is replaced and the rest
is left alone; nothing needs reloading.

## Left Panel Tabs

### Game

Shows the adventure and the group the session currently holds. There is nothing
to select: both arrive from the [PathMapper client](../client/README.md), and the
console plays what it is given.

### Scenes

- **Select**: switch to a scene (state is preserved across switches)
- **Unset**: deactivate the current scene (shows wallpaper)
- **Reset**: re-initialize the scene to its starting state (requires a confirmation click)

### Map

Map layer management:

- **Grid toggle**: show or hide the grid overlay
- **Per-layer controls**: show/hide, bright/dim lighting, highlight
- **Layer hover**: hovering a layer name highlights it on the map
- **Map objects**: collapsible groups per layer
  - Lock/unlock (locked by default, prevents accidental dragging)
  - Show/hide individual objects

### Tokens

- **Add**: add adventure-defined tokens (enemies, NPCs)
- **Players**: add player character tokens (from the loaded group)
- **Extras**: add player extra tokens (markers, companions)
- **Copy**: serializes current token positions as TOML `place_tokens` for the manifest (see [Adventures: The Copy button](adventures.md#the-copy-button))
- Below the buttons, the list of placed tokens is always visible with state controls and delete

## Right Panel

- **Group overview**: shows all characters with portraits, names, and classes
- **Snap-to-grid toggle**: controls whether token movement snaps to grid cells

## Token Interactions (On the Map)

- **Drag** to move tokens
- **Double-click** to select in the manage panel
- **Right-click** context menu: set state (alive/unconscious/dead/hidden), delete

## Map Object Interactions (On the Map)

- **Drag** to move (when unlocked via the Map panel)
- **Right-click** context menu: lock/unlock, show/hide, reset position

## Keyboard Shortcuts

- **Escape**: close the left panel

Click outside panels to close them.

## Content Upload

1. Edit the adventure or group on your own machine
2. Upload it again with the client --- `path-mapper my-adventure.pmadventure`, or a
   double-click
3. No server restart needed

Uploading again replaces what the ids name and leaves everything else alone, so an
edit reaches a running session without restarting it. Where a scene has gone, its
placements go with it.

## What Your Players See

### Accessing the Player View

Open `http://your-server:4000/` in a browser.

### What Players See

- The active scene map (if one is selected by the GM)
- Visible tokens (hidden tokens are invisible to players)
- Visible map objects (hidden objects are invisible to players)
- Adventure wallpaper (when no scene is active)

### Right Panel

- Group overview (same as GM view)
- Snap-to-grid toggle (local to each viewer)

### What Players Cannot Do

- No left panel (no adventure/group/scene selection)
- Cannot manage tokens, layers, or objects
- Cannot see hidden tokens or hidden map objects

### Real-Time Updates

Everything the GM does is reflected immediately on the player view. Players should keep their browser tab open during the session.
