# Tokens

A token is a PNG. It reaches a session in one of two ways: uploaded on its own
as a `.pmtoken`, or brought along by a [character](characters.md) that names
it.

A token is declared once and placed as often as you like. Declaring it puts it
on the shelf; it stands on nothing until someone places it.

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

The id is `[a-z]{2}[0-9]{4}-[0-9]{10}` and is global. Every piece takes its id
from its filename, and a file with no id in its name is refused.

The descriptive half is the fallback name: `tk0001-0000000042-crooked-ear.png`
becomes "crooked ear" if the PNG says nothing about itself.

That fallback applies to a `.pmtoken` uploaded on its own. A token a
[character](characters.md) names is called whatever the character calls it:
the character names and owns what it points at, because the token's own bytes
cannot know which character is using them.

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
| `owner` | `enemy`, `npc`, `none`, or a character's id          | `npc`                                |

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
Tokens panel, which lists every token the session holds and has a search.
Uploading again under the same id replaces the image everywhere it is used —
which is how you fix artwork mid-session.

## A token versus a placement

A **token** is a thing that may be placed: an image, a name, a size, an owner.

A **placement** is that token on a surface. One token may be placed many times,
and each placement has its own identity, position, state, owner and name. Four
goblins from one token are four placements.

Placements are made during play, from the GM's Tokens panel, and by players
adding their own character token and markings. Nothing declares a placement in
advance --- a token exists, and where it stands is something that happened. A
[load list or a snapshot](sessions.md) does carry where everything stood, so a
session can be put back as it was.

Naming a placement — "the crooked-ear one" — is done from the Tokens panel and
changes nothing about the token itself or any other placement of it.
