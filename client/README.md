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

Then write `~/.config/pathmapper/config.toml`:

```toml
server = "http://localhost:4000"
token = "the server's API_TOKEN"
snapshots = "~/snapshots"
```

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
path-mapper the-train.pmadventure hard-divers.pmgroup
path-mapper snapshot
path-mapper reset
```

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
does not really have, but `tEXt`, `zTXt` and `iTXt` chunks, which is where an image
editor puts a title.

| chunk keyword | becomes      |
|---------------|--------------|
| `Title`       | the token's name |
| `Size`        | how many grid cells across it is |

Neither is required. Without a `Title` the name is the descriptive half of the
filename — `tk0001-0000000042-goblin-chief.png` becomes "goblin chief" — and
without a `Size` it is one cell. A size that is not a positive whole number is
ignored rather than refused: the file is still a perfectly good token.

Both are defaults. A scene that uses the token can override its name, size or owner
for that scene alone, which is what lets one token be an NPC by default and a
player's where a scene says so.

## Failure

Everything goes to stderr with a non-zero exit status, because the callers are a
file manager and a GIMP plug-in and neither has a console. The plug-in shows
whatever comes back here, so one program decides how a failure reads.
