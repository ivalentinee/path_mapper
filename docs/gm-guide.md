# GM Session Guide

This guide covers running a game session using the GM interface.

## Accessing the GM View

Open `http://your-server:4000/master` in your browser.

## Interface Overview

- **Left panel** (GM-only): Game, Scenes, Map, Tokens, Initiative
- **Right panel** (shared with players): Group, Initiative, and the tool strip
- **Surface indicator** (top): the name of the surface the table is on; click it to open the surface list
- **Wallpaper**: shown whenever no surface is active

## Session Workflow

1. Upload your pieces with the [client](client.md) --- a directory, a
   single map or token, or a [`.pmload`](sessions.md) naming a session you
   prepared earlier. There is nothing to select here, since the console issues
   no commands
2. Open left panel > **Scenes** > select a surface
3. Add character tokens: Tokens panel > Players > "All" or individually
4. Play the session

To change what the session holds mid-game --- a new map, a fixed token image, a
different party --- upload it again. What is re-declared is replaced and the rest
is left alone; nothing needs reloading.

Uploading never changes what the table is looking at. A new map joins the list,
and you switch to it when you are ready.

## Left Panel Tabs

### Game

What the session currently holds, counted by kind: maps, tokens, characters and
whether there is a wallpaper. There is nothing to select --- every piece arrives
from the [PathMapper client](client.md), and the console plays what it
is given.

### Scenes

The surfaces the session holds, which are simply its maps, listed by id order. A
map reaches this list by existing; nothing enumerates them, and a map with no
name is listed by its id.

- **Select**: switch to a surface (state is preserved across switches)
- **Unset**: deactivate the current surface (shows the wallpaper)
- **Reset**: re-initialize the surface to its starting state (requires a confirmation click)

### Map

Map layer management:

- **Grid toggle**: show or hide the grid overlay
- **Per-layer controls**: show/hide, bright/dim lighting, highlight
- **Layer hover**: hovering a layer name highlights it on the map
- **Map objects**: collapsible groups per layer
  - Lock/unlock (locked by default, prevents accidental dragging)
  - Show/hide individual objects

### Tokens

- **Add**: every token the session holds, with a search. There is no per-surface
  shortlist --- a map carries no token roster
- **Players**: add character tokens, one at a time or all at once
- **Extras**: add a character's markings (markers, companions)
- **Copy**: puts the current arrangement of tokens on the clipboard as TOML.
  Nothing reads it back --- the format it was written for is gone --- so treat
  it as a scratch note. To keep an arrangement, write it down ---
  `path-mapper save <name>` or `path-mapper snapshot`, see
  [Preparing a Session](sessions.md)
- Below the buttons, the list of placed tokens is always visible with state controls and delete

### Initiative

The initiative order, which is game state like anything else on a surface.

## Right Panel

- **Group**: every character the session holds, with portraits, names, classes
  and Charkeeper stats where they are configured
- **Initiative**: the current order
- **Tool strip**: measuring tools, the map tool, drawing tools with width and
  colour, undo, the snap-to-grid toggle, and zoom

## Token Interactions (On the Map)

- **Drag** to move tokens
- **Double-click** to select in the manage panel
- **Right-click** context menu: set state (alive/unconscious/dead/hidden), delete

## Map Object Interactions (On the Map)

- **Drag** to move (when unlocked via the Map panel)
- **Right-click** context menu: lock/unlock, show/hide, reset position

## Keyboard Shortcuts

- **Escape**: unwind one level --- clear a pending digit, close the open panel, or deselect the active tool

Click outside panels to close them.

## Content Upload

1. Edit the piece on your own machine
2. Upload it again with the client --- `path-mapper <file>`, or a
   double-click
3. No server restart needed

Uploading again replaces what the ids name and leaves everything else alone, so an
edit reaches a running session without restarting it. Re-uploading a map rebuilds
the surface on it and carries the tokens, drawings and moved objects across.

Removing a single piece is a server command the client does not wrap yet ---
`DELETE /api/entities/:id`. `path-mapper reset` empties the board entirely.

## What Your Players See

### Accessing the Player View

Open `http://your-server:4000/` in a browser.

### What Players See

- The active surface (if you have selected one)
- Visible tokens (hidden tokens are invisible to players)
- Visible map objects (hidden objects are invisible to players)
- The wallpaper, when no surface is active

### Claiming a Character

A player is a browser session that has claimed a character --- nothing stores the
claim, and you do not assign it. In the player view, Group panel, each character
offers a **"That's me!"** button; after claiming, that player gets a **Character**
panel with their portrait, their stats, a button to put their token on the map or
take it off, and their extra tokens.

Closing the tab releases the claim.

### Right Panel

- Group (same as the GM view, plus the claim buttons)
- Character (once they have claimed one)
- Initiative
- Tool strip: measuring and drawing tools, a grid toggle, snap-to-grid and zoom

### What Players Cannot Do

- No left panel (no surface selection, no map or token management)
- Cannot manage tokens other than their own character's and its extras
- Cannot see hidden tokens or hidden map objects

### Real-Time Updates

Everything the GM does is reflected immediately on the player view. Players should keep their browser tab open during the session.
