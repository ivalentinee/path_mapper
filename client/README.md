# PathMapper client

The other half of PathMapper. The server holds nothing of its own: adventures,
groups, maps, tokens and snapshots live on the game master's machine, and this
sends them over when a session needs them.

It is not a library the server shares. It is a program the desktop runs.

## Install

```sh
bundle install
ln -s "$PWD/bin/path-mapper" ~/.local/bin/path-mapper
./desktop/install.sh
```

`install.sh` registers the five `.pm*` types and three desktop entries for your user
alone — no root, and nothing written outside `~/.local/share` and `~/.config`. Check
it took with `xdg-mime query filetype something.pmadventure`, which should answer
`application/x-pathmapper-adventure` rather than `application/zip`.

Symlink it and run it; there is no `bundle exec` and no wrapper script. `bin/path-mapper`
names its own Gemfile and activates only the runtime group, so it works from any
directory, through a symlink, and under the near-empty environment a file manager or
a GIMP plug-in gives it.

Then write `~/.config/pathmapper/config.toml`:

```toml
server = "http://localhost:4000"
token = "the server's API_TOKEN"
snapshots = "~/snapshots"

# Optional, in seconds. The defaults are shown.
open_timeout = 30     # giving up on a server that will not answer at all
read_timeout = 300    # giving up part-way through a request
write_timeout = 300
```

The read timeout is the generous one on purpose: the largest thing that crosses
the wire is one map, and a game master's uplink is not a data centre's. The
connect timeout is short by comparison, because a host that has not answered in
half a minute is down, and waiting longer only delays saying so. A value of zero
or less means "wait for ever" to Ruby, so it is ignored in favour of the default.

The token lives here and nowhere else — not in this repository, and not in a
`.desktop` file, where a command line is readable by anyone who can list
processes.

## Use

| what                  | how                                              |
|-----------------------|--------------------------------------------------|
| an adventure or group | double-click the `.pmadventure` or `.pmgroup`     |
| a token               | double-click the `.pmtoken`                       |
| a map                 | GIMP → File → Upload to Path Mapper, or a `.pmmap` |
| fetch a snapshot      | the "Fetch PathMapper snapshot" entry             |
| clear the server      | the "Reset PathMapper" entry                      |

Or from a terminal, which nothing requires:

```sh
$ path-mapper the-train.pmadventure
the-train.pmadventure -> adventure
  [1] maps/mp0001-0000000001-engine-car.ora (4.2 MB) ... ok
  [2] tokens/tk0001-0000000001-conductor.png (18.4 KB) ... ok
  [3] declaring 47 entities ... ok
Adventure loaded: The Train (12 scenes, 34 tokens, 12 maps, 61 assets uploaded)

$ path-mapper snapshot
Snapshot created: /home/gm/snapshots/snapshot-cp01-010000-cp01-020000-20260921T204113.pmsnapshot

$ path-mapper reset
Server reset: it now holds nothing
```

Every command says what it did rather than what it was given, because a run that
printed nothing and a run that failed silently look the same. Failures go to stderr
with a non-zero exit status.

Each asset is named on its own line before it is sent, and the line is closed with
`ok` or `FAILED` once the answer is in. Uploading an adventure over a slow link is
minutes of waiting, and a progress line is the difference between a client that is
working and a client that has hung — and, when something does go wrong, the last
line printed is the thing it went wrong on.

One connection carries the whole run. Every request used to open its own, which
on a remote server meant a TCP connection and a TLS handshake per asset, and gave
each of them its own opportunity to time out. If the server drops a kept-alive
connection between requests, the client reconnects and re-sends once: every route
here is idempotent, since an asset is stored under the hash of its bytes and an
entity replaces itself by id.

## What it does with a blob

A blob never crosses the wire. The client unpacks it in memory, uploads each
asset the manifest actually names — under the name its bytes hash to — and then
posts a description naming those assets by address.

Source files sitting beside their exports are not uploaded, because nothing names
them.

Ids travel explicitly. Every id used to be read off a filename, and content
addressing destroys filenames, so they are read here while the original names
still exist. That is also why re-uploading works: the id stays put while the
address moves, so a browser fetches the new bytes without being told to.

An `.ora` is uploaded whole. It is one asset even though it is not one image, and
splitting it is the server's business.

## What a token says about itself

A `.pmtoken` is a PNG, and a PNG can carry text about itself — not EXIF, which PNG
does not really have, but `tEXt`, `zTXt` and `iTXt` chunks. PathMapper reads one
keyword, `Comment`, holding a `|`-separated list of settings:

```
name: Зомби-ходок | size: 1 | owner: enemy
```

| setting | becomes                                  | when absent                      |
|---------|------------------------------------------|----------------------------------|
| `name`  | what the token is called                 | the descriptive half of the name |
| `size`  | how many grid cells across it is         | one cell                         |
| `owner` | which side it belongs to                 | `npc`                            |

One keyword rather than one per setting, because one is what an image editor
offers on the way out: GIMP puts a comment field in its export dialog, where a
keyword apiece meant a trip through the metadata editor — and ImageMagick refuses
to write a `Size` keyword at all.

Every setting is optional and order does not matter. Keys are matched ignoring
case and surrounding space. A size that is not a positive whole number is ignored
rather than refused, an unrecognised setting is left alone, and a comment that is
ordinary prose yields no settings — the file is still a perfectly good token, and
`tk0001-0000000042-goblin-chief.png` still becomes "goblin chief".

These are defaults. A scene that uses the token can override its name, size or
owner for that scene alone, which is what lets one token be an NPC by default and
a player's where a scene says so.

## Failure

Everything goes to stderr with a non-zero exit status, because the callers are a
file manager and a GIMP plug-in and neither has a console. The plug-in shows
whatever comes back here, so one program decides how a failure reads.
