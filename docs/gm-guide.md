# GM Session Guide

This guide covers running a game session using the GM interface.

## Accessing the GM View

Open `http://your-server:4000/master` in your browser.

## Interface Overview

- **Left panel** (GM-only): Adventures, Groups, Scenes, Map, Tokens
- **Right panel** (shared with players): Group overview, Snap-to-grid toggle
- **Scene indicator** (top): shows current scene name, click to open scene selector
- **Wallpaper**: displayed when no scene is active

## Session Workflow

1. Open left panel > **Adventures** > select an adventure
2. Open left panel > **Groups** > select a group
3. Open left panel > **Scenes** > select a scene
4. Add player tokens: Tokens panel > Players > "Add All" or individually
5. Play the session

## Left Panel Tabs

### Adventures

Select which adventure to load from the dropdown list. The **Reload** button refreshes the file list from disk --- use this after uploading new ZIP files to the server.

### Groups

Select which group to load. The **Reload** button refreshes the file list from disk.

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
- **Copy**: serializes current token positions as TOML `place_tokens` for the manifest (see [Adventures: Copy Button Workflow](adventures.md#the-copy-button-workflow))
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

1. Copy new or updated ZIP files to the server's `adventures/` or `groups/` directories
2. Click the **Reload** button in the Adventures or Groups panel to pick up changes
3. No server restart needed

Reloading the list does **not** affect the currently active adventure or group --- the GM must re-select to pick up updated content.

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
