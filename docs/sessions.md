# Preparing a Session

You do not write a session down in advance. You load its pieces, arrange the
table until it looks the way it should when play starts, and then ask the
client to write down what it is looking at.

```sh
path-mapper ~/campaigns/the-train/*   # the pieces, in any order
#   …place the tokens, pick the surface the players open on…
path-mapper save the-train            # writes the-train.pmload
```

Next week, that one file is the whole session:

```sh
$ path-mapper the-train.pmload
tk0001-0000000001-conductor.pmtoken -> token
  [1] tk0001-0000000001-conductor.pmtoken (18.4 KB) ... ok
Token loaded: Conductor (1 cell)
mt0001-0000000001-engine-car.pmmap -> map
  [2] mt0001-0000000001-engine-car.pmmap (4.2 MB) ... ok
Map loaded: engine car
  [3] applying game state ... ok
Loaded: 2 pieces
```

This is why there is no package format. A package was authored before anything
had been seen; a load list is taken from a session that already works.

## The file

A `.pmload` is a **load list**: TOML you can read and edit, naming the pieces
rather than carrying them. Three keys, all optional:

```toml
load = ["the-campaign.pmload"]    # other lists, read first

pieces = [
  # maps
  "mt0001-0000000001",            # engine car
  # tokens
  "tk0001-0000000001",            # Conductor
]

game_state = "{\"version\":4,…}"  # the server's own dump, as one string
```

`pieces` **names** things; it never describes them. Each entry is resolved the
way every reference in PathMapper is resolved:

- **an id** --- `mt0001-0000000001` --- looked up in your
  [library](client.md#where-it-keeps-things)
- **a path** --- `nights/01/engine-car.pmmap` --- taken relative to the
  `.pmload` itself

The grouping comments and the names after each id are **for you**. The client
reads the ids and nothing else, so a name that has gone stale is wrong in a
comment rather than wrong in a session.

`game_state` is written and read by the program. Edit the lists by hand; leave
that one alone.

A `.pmload` may also be written as JSON, which is what to generate if you are
scripting one and would rather not reach for a TOML library. The client tells
them apart by looking at the file.

## Load list or snapshot

Both restore a table. They differ in what they carry, and the difference is the
whole point.

|                               | `.pmsnapshot`                             | `.pmload`                            |
|-------------------------------|-------------------------------------------|--------------------------------------|
| holds                         | the pieces' **bytes**                     | the pieces' **names**                |
| size                          | the whole session                         | a page of text                       |
| repaint a map, keep its id    | still opens the old artwork               | every list naming it picks up the new |
| needs your library            | no --- it is self-contained                | yes                                  |
| edit by hand                  | no                                        | that is what it is for               |
| made                          | during play, from the GM view             | from a terminal, with `save`         |

A snapshot is a photograph; a load list is a recipe.

- Take a **snapshot** when you want *that evening* back exactly as it was, or
  when you are handing the session to a machine that does not have your
  library.
- Write a **load list** when you want *that session* again, as its pieces are
  today.

The second is the one that changes how you work. Repaint a map in GIMP, keep
its id, upload nothing --- the next time any list naming it is loaded, the new
artwork arrives. Nothing has to be rebuilt, and no list has to be touched.

## Composing by hand

Nothing requires `save`. A `.pmload` naming three ids is a valid session, and
an index that loads several is how a campaign holds its nights:

```toml
# the-campaign.pmload
load = [
  "nights/01-the-train.pmload",
  "nights/02-the-bridge.pmload",
]

pieces = [
  "pg0001-0000000001-the-party.pmcharacter",   # everyone, every night
]
```

The order is fixed and worth knowing:

1. **`load` first** --- nested lists, depth first
2. **then `pieces`** --- this file's own
3. **then `game_state`** --- last at every level

Because state is applied last at each level, the **outermost file wins**: the
list you name on the command line decides where the table starts, whatever the
lists under it were saved with.

A name nothing answers to is reported and skipped; the rest of the session
still loads:

```
  nothing named mt9999-0000000099
Loaded: 6 pieces
```

That is deliberate. A list is a long enough thing that stopping at the first
gap would mean learning about them one game night at a time.

Nothing stops a list from loading itself. If you write that, it recurses ---
the client does not check, because a self-referencing list is a mistake in the
file rather than a case to handle.

## Characters are referenced, never declared

Name the `.pmcharacter` and the tokens it owns arrive with it. `save` leaves
those tokens out of `pieces` for the same reason: the character already knows
them, and a second copy is the one that drifts.

So a party that changes between nights changes in one place --- the character
file --- and every list naming it follows.

## See also

- [The Client](client.md) --- the program, the library, and the rest of what it does
- [GM Guide](gm-guide.md) --- running the session once it is loaded
- [Characters](characters.md) --- the file a load list points at
