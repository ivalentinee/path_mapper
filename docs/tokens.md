# Tokens

A token is a PNG. It reaches a session in one of three ways: declared by an
adventure, declared by a group as a player's, or uploaded on its own.

## The image

- **Format:** PNG with a transparent background
- **Shape:** round, since the board draws tokens as circles
- **Size:** 200–400 pixels a side balances quality against upload size

## The filename carries the id

```
tk0001-0000000042-goblin.png
└──────┬────────┘ └───┬────┘
       id         description
```

The id is `[a-z]{2}[0-9]{4}-[0-9]{10}` and is global — see
[Adventures](adventures.md#identity-every-id-comes-from-a-filename). A file
without one cannot be placed.

The descriptive half is the fallback name: `tk0001-0000000042-crooked-ear.png`
becomes "crooked ear" if the PNG says nothing about itself.

## What a PNG may say about itself

PNG has no EXIF. It keeps text in `tEXt`, `zTXt` and `iTXt` chunks, and PathMapper
reads one of them: **`Comment`**, holding a `|`-separated list of `key: value`
settings.

```
name: Зомби-ходок | size: 1 | owner: enemy
```

| Setting | Meaning                                              | When absent                          |
|---------|------------------------------------------------------|--------------------------------------|
| `name`  | What the token is called                             | the descriptive half of the filename |
| `size`  | Size in grid cells: 1 standard, 2 large              | 1                                    |
| `owner` | `enemy`, `npc`, `none`, or a player id from the group | `npc`                                |

All three are optional, in any order. Keys are matched ignoring case and
surrounding space; a value keeps its own spacing, so a name may contain any.

One property rather than one per setting because that is what an image editor
offers on the way out — see below. Settings PathMapper does not recognise are
ignored rather than refused, and a comment that is ordinary prose simply yields
none.

`size` must be a positive whole number; anything else falls back to 1 rather than
refusing the file, since a bad value is not worth failing an upload over.

### Setting it in GIMP

**File → Export As…**, and in the PNG options fill in **Comment**. That is the
whole of it — no trip through the metadata editor.

### Setting it with ImageMagick

```sh
magick goblin.png -set 'Comment' 'name: Crooked ear | size: 2 | owner: enemy' \
  tk0001-0000000042-goblin.png
```

### Checking what a file says

```sh
magick identify -verbose tk0001-0000000042-goblin.png | grep -A2 Properties
```

UTF-8 is read correctly even though the PNG specification says those chunks are
latin-1, because most editors write UTF-8 regardless. A name in Cyrillic or with
combining accents survives.

## Uploading one on its own

```sh
path-mapper tk0001-0000000042-goblin.pmtoken
```

Or double-click it. The token joins the session and can be placed from the GM's
Tokens panel. Uploading again under the same id replaces the image everywhere it
is used — which is how you fix artwork mid-session.

## A token versus a placement

A **token** is a thing that may be placed: an image, a name, a size, an owner.

A **placement** is that token on a map. One token may be placed many times, and
each placement has its own identity, position, state, owner and name. Four
goblins from one token are four placements.

Placements are written in a scene's `place_tokens`
([Adventures](adventures.md#tokens-the-scene-starts-with)) and made during play
from the Tokens panel. Naming one — "the crooked-ear one" — is done from that
panel and changes nothing about the token itself or any other placement of it.
