# Map Construction

A map is an ORA (OpenRaster) file with specially named layers.

A map is also **the playable surface**: there is nothing between a map and what
happens on it. Its id — read from its filename — is the surface's id, and
everything else about it is read out of the file. Uploading a map adds a surface;
there is no other way to add one.

## Recommended Tool

- **GIMP** 3.2 or later ([download](https://www.gimp.org/downloads/)) — best texture painting workflow (pattern stamp), built-in ORA export, layer groups for map objects. Use a pre-saved `.xcf` template with the `[L1]`/`[G]`/`[F]` layer structure.

## Canvas Dimensions

- **Typical battle map:** 2000x2000 pixels
- The canvas size, combined with the grid cell size, determines the playable area. For example, a 2000x2000 canvas with `[grid-50]` gives a 40x40 grid.
- Layers do not need to be full-canvas-size --- ORA preserves each layer's x/y offset and dimensions.

## ORA Layer Naming Convention

Path Mapper uses a bracket prefix system to identify layers. Each layer in the GIMP Layers panel must be named according to this convention.

### Prefixes

| Prefix | Meaning                     | Context                        |
|--------|-----------------------------|--------------------------------|
| `[LN]` | Map layer (N = layer index) | Top-level layer or layer group |
| `[B]`  | Base image                  | Inside a layer group           |
| `[G]`  | Grid overlay                | Top-level layer                |
| `[F]`  | Fog of war                  | Top-level layer                |
| `[M]`  | The map's name and address  | Top-level layer                |

Objects inside a layer group have **no prefix** --- any layer inside an `[LN]` group that is not tagged `[B]` is treated as a map object.

### Layer Tags

Tags are suffix annotations in square brackets. Each tag goes in its own bracket
pair. All of them are single words except `[link ...]`, which carries a list --- see
**Links** below.

| Tag              | Description                                                                                                           |
|------------------|-----------------------------------------------------------------------------------------------------------------------|
| `[hide]`         | Layer hidden by default                                                                                               |
| `[dim]`          | Layer dimmed by default                                                                                               |
| `[floor-N]`      | Assigns layer to floor N (enables floor switching)                                                                    |
| `[grid-N]`       | Sets grid cell size to N pixels (default: 50)                                                                         |
| `[grid-line-N]`  | Sets grid line width to N pixels (default: 1). Tokens are inset by half this value so they don't overlap grid lines.  |
| `[grid-hide]`    | Hides the grid overlay by default                                                                                     |
| `[link ...]`     | Makes a map object a way through to another map --- see **Links** below                                               |

Grid tags (`[grid-N]`, `[grid-line-N]`, `[grid-hide]`) are searched across all top-level layers, not just the `[G]` layer. The `[G]` layer is the recommended location by convention. `[B]` base sublayers inside groups are **not** searched for tags.

**Defaults** (when no tags are specified): grid cell size = 50 pixels, grid line width = 1 pixel.

### Links

A map object can be a way through to another map. Write a `link` tag on it, with the
target map's id last:

```
Tavern [link mt0001-0000000002]
```

The game master right-clicks the object, and the menu that already offers lock, show
and reset offers `➜` as well. Taking it puts the table on that map. Nothing moves on
the right-click itself.

An object carrying a link is marked --- the cursor changes over it and it brightens
on hover --- so a reader can tell a place that leads somewhere from one that is
painted on.

**The object still needs a name of its own.** `Tavern [link ...]` works;
`[link ...]` alone does not, and the map is refused with *name: can't be blank*. The
name is what the object is called, and stripping the tags off must leave something.

**Where the tag goes.** On the object, which is a layer *inside* an `[LN]` group ---
not on the group, and not on a top-level layer. `Tavern [L1] [link ...]` is wrong:
the `[L1]` would make it a layer rather than an object.

#### Link properties

Anything between `link` and the target is a property, written in one of three ways:

| Written              | Means                                      |
|----------------------|--------------------------------------------|
| `property`           | present, which is true                     |
| `property=value`     | a value carrying no whitespace             |
| `property="value"`   | a value that may carry whitespace          |

Two are understood today:

| Property  | Effect                                                                 |
|-----------|------------------------------------------------------------------------|
| `gm`      | The link is yours alone --- a player sees the object as ordinary scenery |
| `title`   | Shown as a tooltip when anyone who can see the link hovers it            |

```
Abandoned Castle [link gm title="Nobody has been here in years" mt0001-0000000003]
```

Anything else you write is kept and ignored, so a tag written for a later version
still loads today.

**A quoted value may not contain `]`.** The tag ends at the first closing bracket,
whatever quoting is around it, so `title="The Keep [ruined]"` cuts the tag short and
the remainder lands in the object's name.

**A link to a map you have not uploaded yet does nothing.** It is not an error ---
maps are often drawn before the places they point at exist --- and `➜` simply leaves
the table where it is until the other map arrives. Nothing reports it, so a mistyped
id and a map not yet sent look the same.

### Flat Layers (No Objects)

A simple map with no interactive objects uses flat layers:

```
[L3] Roof
[L2] Upper Floor [hide] [floor-2]
[L1] Ground Floor [floor-1]
[G] Grid [grid-50] [grid-line-2]
[F] FOW
```

Each `[LN]` layer is a single image. Layers are rendered bottom-to-top (L1 first, L3 last).

### Grouped Layers (With Map Objects)

To add interactive objects (doors, tables, barrels), use a GIMP layer group:

```
[L1] Ground Floor [floor-1]
  Chairs                          <- object (no prefix needed)
  Table                           <- object (no prefix needed)
  [B] Walls                       <- base image (part of the layer)
  [B] Floor                       <- base image (part of the layer)
```

- **`[B]` layers** are base images that form the layer itself. Multiple `[B]` layers are supported --- they stack in ORA order. These are not interactive; they follow the layer's display state.
- **Unlabeled layers** (no bracket prefix) are map objects. They automatically belong to the group's layer index.

### Full Example

```
[L3] Roof
[L2] Upper Floor [hide] [floor-2]
[L1] Ground Floor [floor-1]
  Chairs                          <- map object
  Table                           <- map object
  [B] Walls                       <- base image
  [B] Floor                       <- base image
[G] Grid [grid-50] [grid-line-2]
[F] FOW
```

## Map Objects

Map objects are interactive environmental props: doors, tables, barrels, furniture. They are extracted from unlabeled layers inside `[LN]` groups.

- **Locked by default** --- the GM must unlock objects before dragging
- **Inherit layer visibility** --- hiding a layer hides its objects
- **Per-object visibility** --- the GM can show/hide individual objects
- **Draggable** (when unlocked) --- the GM can reposition objects on the map
- **Reset position** --- return an object to its original ORA coordinates

## Grid and Special Layers

- **Grid** (`[G]`): rendered above all map layers and objects
- **Fog of War** (`[F]`): rendered below all map layers
- **Metadata** (`[M]`): never rendered --- it carries words, not pixels

### What a map says about itself

A map can carry its own name and the address of a page describing it. Both live
on one top-level layer, and both are optional:

```
[M] Crow's Keep [url https://example.com/places/crows-keep]
```

The layer's own name is the map's name. Path Mapper shows it to the game master
when they right-click something that links here, so a worldmap pin reads as a
place rather than as an id.

The `[url ...]` tag is a page you publish somewhere built for publishing --- a
Jekyll site, a wiki, anything that serves a URL. Path Mapper does not render
descriptions; it opens the address in a new tab.

Either half may be left out. `[M] Crow's Keep` names the map and offers no
address; a map with no `[M]` layer keeps the name its filename gave it.

**The layer is never drawn.** Nothing on it appears on the board, whatever you
paint there --- so leave it empty.

**A `]` ends a tag.** A URL containing one must be percent-encoded as `%5D`.
Everything else survives, including non-ASCII: `[M] Крепость [url
https://example.com/крепость?a=1&b=2]` works as written.

## Creating a Map in GIMP

### Using a Template (.xcf)

[`template.xcf`](template.xcf) ships with the documentation and has the whole
structure built. `client/desktop/install.sh` copies it into your library, so
`path-mapper map new` can reach it without you doing anything.

It is:

```
[M] Map name
[G] Grid [grid-50] [grid-line-1]
[F] Fog of War
[L5] Environment 3
[L4] Environment 2
[L3] Environment 1
[L2] Room
  [B] Walls
[L1] Ground
  [B] Floor
```

Open it and **Save As** under a new name carrying the map's id ---
`mt0001-0000000001-tavern.xcf` --- then draw.

**During a session, let the client do that**: `path-mapper map new "crow's keep"`
copies the template, names it for an id nobody has to invent, and opens GIMP on
it. See the [client documentation](client.md).

**Rename the `[M]` layer.** A map saved from the template without touching it is
called "Map name" on the board --- which is the point: the placeholder is there to
be seen and edited, rather than a bare `[M]` you would never notice. Rename it, or
delete the layer to have the map named by its filename instead.

The template carries no `[url ...]`, so a new map offers no link until you add
one.

### Simple Map (Flat Layer)

1. Open your template `.xcf`, File > Save As to a new name
2. Or: File > New, set dimensions (e.g. 2000x2000), rename the default layer to `[L1] Background`
3. Paint your map (use the pattern stamp tool for floor textures)
4. File > Export As > choose **OpenRaster (.ora)** format

### Map with Objects (Layer Group)

1. Create your image as above
2. Create a layer group: Layer > New Layer Group. Name it `[L1] Ground Floor`
3. Inside the group, create layers for base images (name them `[B] Floor`, `[B] Walls`, etc.)
4. Inside the same group, create layers for objects (name them without brackets: `Table`, `Door`, etc.)
5. Paint each layer
6. Export as ORA

### Adding a Grid

1. Create a new layer at the top of the layer stack
2. Name it `[G] Grid [grid-50]` (50 = grid cell size in pixels)
3. Draw your grid on this layer. Path Mapper uses this image as the grid overlay. The layer name carries the grid configuration tags.
4. To change the grid line width: `[G] Grid [grid-50] [grid-line-2]`

## Uploading a Map to Path Mapper

A map arrives the way every piece does: its bytes go up as an asset, and an
entity naming them declares the surface. The map's id is the surface's id, and
it comes from the filename.

### Server Setup

Set the `API_TOKEN` environment variable before starting Path Mapper:

```bash
API_TOKEN=my-secret-token mix phx.server
```

The [client](client.md) needs the same value in its own config.

### Upload the working file

Name the `.xcf` for the map's id and hand it to the client. There is no export
step — the client runs GIMP headlessly and converts the file on the way.

1. Draw your map in GIMP using the layer naming conventions above.
2. **File → Save As…**, naming the file with an id:
   `mt0001-0000000001-tavern.xcf`.
3. Upload it:

   ```sh
   path-mapper mt0001-0000000001-tavern.xcf
   ```

   Some file managers also offer it under **Open With**, which depends on
   whether yours lists handlers that are not the default.

**Double-clicking a `.xcf` opens GIMP, not PathMapper** --- editing a map is the
commoner thing to want. `install.sh` goes out of its way to keep it that way:
registering for a type is enough to win the default on a session where nothing
has claimed it, so the installer puts the previous answer back and tells you how
to set one if there was none.

**GIMP must be installed on the machine running the client** — that is the one
thing the `.xcf` route needs that the `.pmmap` route does not. Nothing else in
PathMapper depends on it.

### Export and upload, the other way

Still supported, and the only way on a machine with no GIMP.

1. **File → Export As…**, choose **OpenRaster (.ora)**, and name the file with
   an id: `mt0001-0000000001-tavern.ora`.
2. Rename it to `.pmmap`. A `.pmmap` is an OpenRaster file and nothing else.
3. Double-click it, or:

   ```sh
   path-mapper mt0001-0000000001-tavern.pmmap
   ```

Several at once is a directory: `path-mapper ~/campaigns/the-train/*`. Order
does not matter --- each piece carries its own id.

### What uploading does and does not do

Uploading adds the map to the GM's list of surfaces. **It does not switch the
table to it** — there is no route that puts a map onto whatever the table
happens to be looking at. The GM selects the surface from the Scenes panel.

Re-uploading under the same id rebuilds the surface on it: the new layers, grid
and objects take effect, and token positions, drawn elements and moved map
objects are carried across. It works because an edited image has different bytes
and so a different address, while the id stays put — connected browsers fetch
the new image without being told to.

