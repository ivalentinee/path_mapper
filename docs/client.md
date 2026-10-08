# The Client

The other half of PathMapper. The server holds nothing of its own --- maps,
tokens, characters and the sessions they make up live on the game master's
machine, and the client sends them over when a session needs them.

It is not a library the server shares. It is a program the desktop runs.

## Install

```sh
cd client
bundle install
ln -s "$PWD/bin/path-mapper" ~/.local/bin/path-mapper
./desktop/install.sh
```

`install.sh` registers the `.pm*` types and the desktop entries for your user
alone --- no root, and nothing written outside `~/.local/share` and
`~/.config`. Check it took with:

```sh
xdg-mime query filetype something.pmtoken
```

which should answer `application/x-pathmapper-token` rather than
`application/octet-stream`. `.xcf` is listed so a map can be *offered* to
PathMapper, but the installer makes sure it does not become the handler for one
--- double-clicking a `.xcf` still opens GIMP.

Symlink it and run it; there is no `bundle exec` and no wrapper script.
`bin/path-mapper` names its own Gemfile and activates only the runtime group,
so it works from any directory, through a symlink, and under the near-empty
environment a file manager or a menu entry gives it.

## Configuration

Write `~/.config/pathmapper/config.toml`:

```toml
server = "http://localhost:4000"
token = "the server's API_TOKEN"
library = "~/campaigns"

# Optional, in seconds. The defaults are shown.
open_timeout = 30     # giving up on a server that will not answer at all
read_timeout = 300    # giving up part-way through a request
write_timeout = 300
```

The read timeout is the generous one on purpose: the largest thing that crosses
the wire is one map, and a game master's uplink is not a data centre's. The
connect timeout is short by comparison, because a host that has not answered in
half a minute is down, and waiting longer only delays saying so. A value of
zero or less means "wait for ever" to Ruby, so it is ignored in favour of the
default.

**The token lives here and nowhere else** --- not in the repository, and not in
a `.desktop` file, where a command line is readable by anyone who can list
processes.

The client requires nothing from its environment and runs correctly with an
empty one: `env -i path-mapper reset` finds the same configuration a login
shell would. No setting travels in a variable.

## Where it keeps things

**The library is the only path you configure.** Everything else the client
reads or writes is under it, so there is one answer to "where did it put that"
and one directory to move. The rest follow the XDG base directory
specification, so each has a default and none has to be set:

| What                           | Where                                                             | Set by       |
|--------------------------------|-------------------------------------------------------------------|--------------|
| configuration                  | `$XDG_CONFIG_HOME/pathmapper/config.toml`, else `~/.config/…`      | you          |
| desktop entries and MIME types | `$XDG_DATA_HOME/applications`, else `~/.local/share/…`             | `install.sh` |
| the library                    | the `library` key, defaulting to `$XDG_DATA_HOME/path-mapper`      | you          |
| tokens a character names by id | looked up anywhere under the library                              | you          |
| the map template               | `<library>/maps/template.xcf`                                     | `install.sh` |
| maps made during play          | `<library>/maps/pm/`                                              | the client   |
| snapshots                      | `<library>/snapshots/`                                            | the client   |
| what the client remembers      | `$XDG_STATE_HOME/path-mapper/state.toml`, else `~/.local/state/…`  | the client   |
| the icon                       | `$XDG_DATA_HOME/icons/hicolor/256x256/apps/pathmapper.png`        | `install.sh` |

**Nothing else is written anywhere.** A `.xcf` is converted in a temporary
directory that is removed whether the upload succeeded or failed, so no cache
accumulates and there is nothing to clear.

The state file holds two things the program *remembers* rather than two things
you *set*: the last map id it issued, and where it put that map. It is separate
from the configuration so that nothing rewrites a file you own.

## Use

| what                   | how                                                  |
|------------------------|------------------------------------------------------|
| a token                | double-click the `.pmtoken`                          |
| a character or a party | a `.pmcharacter` in org, TOML or JSON                |
| a map                  | a `.xcf` straight from GIMP, or an exported `.pmmap` |
| a whole session        | `path-mapper <directory>/*`, in any order            |
| a session you prepared | a `.pmload` --- see [Preparing a Session](sessions.md) |
| fetch a snapshot       | the "Fetch PathMapper snapshot" entry                |
| clear the server       | the "Reset PathMapper" entry                         |

Or from a terminal, which nothing requires:

```sh
$ path-mapper ~/campaigns/the-train/*
mt0001-0000000001-engine-car.pmmap -> map
  [1] mt0001-0000000001-engine-car.pmmap (4.2 MB) ... ok
Map loaded: engine car
tk0001-0000000001-conductor.pmtoken -> token
  [2] tk0001-0000000001-conductor.pmtoken (18.4 KB) ... ok
Token loaded: Conductor (1 cell)

$ path-mapper save the-train
Load list written: the-train.pmload

$ path-mapper snapshot
Snapshot created: /home/gm/campaigns/snapshots/snapshot-20261007T142756.pmsnapshot

$ path-mapper reset
Server reset: it now holds nothing
```

Every command says what it did rather than what it was given, because a run
that printed nothing and a run that failed silently look the same.

Each asset is named on its own line before it is sent, and the line is closed
with `ok` or `FAILED` once the answer is in. Uploading a session over a slow
link is minutes of waiting, and a progress line is the difference between a
client that is working and a client that has hung --- and, when something does
go wrong, the last line printed is the thing it went wrong on.

One connection carries the whole run. If the server drops a kept-alive
connection between requests, the client reconnects and re-sends once: every
route is idempotent, since an asset is stored under the hash of its bytes and
an entity replaces itself by id.

## A map during play

The players go somewhere nobody prepared.

```sh
path-mapper map new "crow's keep"   # copies the template, opens GIMP
#   …draw, Ctrl+S…
path-mapper map upload              # sends it; no path to remember
```

Or, with no terminal: **New PathMapper map**, draw, save, **Upload the new
PathMapper map**.

The map is `pm0001-<n>-crows-keep.xcf` in `<library>/maps/pm/`. `pm0001` is the
series the client issues ids in, as against the ones you choose yourself --- a
map worth keeping is renamed into your own series afterwards, which gives it a
new id and makes it an ordinary map. Leave the name out and the file is
`pm0001-<n>.xcf`.

`map upload` takes no argument and means the map `map new` last made. If that
file has been moved or deleted it says so rather than guessing at another.

## Reading a `.xcf`

A map handed over as a `.xcf` is converted to ORA by **GIMP, run headless**, and
the ORA is what is uploaded. GIMP is the only thing that reads its own format
correctly, and it is already installed, because it is where the file came from.

Nothing of PathMapper's is installed into GIMP. The conversion travels as a
Python-Fu string on the command line and is gone when the process exits --- no
plug-in, no profile change, nothing to break when GIMP is reinstalled.

The same holds for `.pmcharacter` files written in org: **Emacs, run headless**,
reads them, and gets an `--eval` form rather than an elisp file. Each dependency
is scoped to the one path that wants it --- no `.xcf` means no GIMP, no org
means no Emacs.

## What it does with a piece

The client uploads the bytes under the name they hash to, then posts a
description naming that asset by address. A piece is a file and nothing gathers
them: several at once is a directory, in any order.

Ids travel explicitly. Every id used to be read off a filename, and content
addressing destroys filenames, so they are read here while the original names
still exist. That is also why re-uploading works: the id stays put while the
address moves, so a browser fetches the new bytes without being told to.

An `.ora` is uploaded whole. It is one asset even though it is not one image,
and splitting it is the server's business.

## Failure

Everything goes to stderr with a non-zero exit status, because the callers are
a file manager and a menu entry and neither has a console. One program decides
how a failure reads.
