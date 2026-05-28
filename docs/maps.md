# Map Construction

A map is an ORA (OpenRaster) file with specially named layers. Maps are created in GIMP and exported to ORA format.

## Recommended Tools

- **GIMP** version 2.10 or later ([download](https://www.gimp.org/downloads/))

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

Objects inside a layer group have **no prefix** --- any layer inside an `[LN]` group that is not tagged `[B]` is treated as a map object.

### Layer Tags

Tags are suffix annotations in square brackets. Each tag goes in its own bracket pair:

| Tag              | Description                                                                                                           |
|------------------|-----------------------------------------------------------------------------------------------------------------------|
| `[hide]`         | Layer hidden by default                                                                                               |
| `[dim]`          | Layer dimmed by default                                                                                               |
| `[floor-N]`      | Assigns layer to floor N (enables floor switching)                                                                    |
| `[grid-N]`       | Sets grid cell size to N pixels (default: 50)                                                                         |
| `[grid-line-N]`  | Sets grid line width to N pixels (default: 1). Tokens are inset by half this value so they don't overlap grid lines.  |
| `[grid-hide]`    | Hides the grid overlay by default                                                                                     |

Grid tags (`[grid-N]`, `[grid-line-N]`, `[grid-hide]`) are searched across all top-level layers, not just the `[G]` layer. The `[G]` layer is the recommended location by convention. `[B]` base sublayers inside groups are **not** searched for tags.

**Defaults** (when no tags are specified): grid cell size = 50 pixels, grid line width = 1 pixel.

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

## Creating a Map in GIMP

### Simple Map (Flat Layer)

1. File > New, set dimensions (e.g. 2000x2000)
2. In the Layers panel, double-click the default layer name and rename it to `[L1] Background`
3. Paint your map
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
