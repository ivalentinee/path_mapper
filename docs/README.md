# Path Mapper Documentation

Path Mapper is a lightweight, playback-only Virtual Tabletop (VTT) for
Pathfinder 2e and other square-grid TTRPGs. All content --- maps, tokens,
characters and a wallpaper --- is authored externally with text editors and
GIMP, and uploaded into a running session by the [client](client.md).

A session is a flat set of pieces, of four kinds:

- **maps** --- each one a playable surface; the map's id is the surface's id
- **tokens** --- images that can be placed on a surface, as often as you like
- **characters** --- who is in the game, naming their tokens by id
- **wallpaper** --- what a viewer sees when no surface is active

None of the four contains another, and each arrives on its own. Nothing
gathers them: a session is a set of files you hand over, and a **load list**
(`.pmload`) is how you write down which pieces it was and where everything
stood.

The server holds nothing of its own. There is no library and no content
directory: what a session contains is what a client has put there, and a
restart leaves an empty board.

## Reading Order

If you are new to Path Mapper, read these in order:

1. [Quick Start](quick-start.md) --- make your first map and run a session
2. [The Client](client.md) --- the program that feeds the server: install, configuration, and the library
3. [Characters](characters.md) --- who is at the table, in any of three formats
4. [Maps](maps.md) --- map construction in GIMP and the ORA layer naming convention
5. [Tokens](tokens.md) --- token images and the PNG keys they may carry
6. [Preparing a Session](sessions.md) --- composing one, writing it down, and loading it again next week
7. [GM Guide](gm-guide.md) --- running a game session, including what your players see

## By Task

| I want to…                                  | Read                                      |
|---------------------------------------------|-------------------------------------------|
| get something on screen today                | [Quick Start](quick-start.md)             |
| draw a map                                   | [Maps](maps.md)                           |
| link one map to another                      | [Maps → Links](maps.md#links)             |
| make a map mid-game                          | [The Client](client.md#a-map-during-play) |
| name a token, or set its size and owner      | [Tokens](tokens.md)                       |
| set up the party                             | [Characters](characters.md)               |
| save tonight's setup and reload it next week | [Preparing a Session](sessions.md)        |
| keep an exact record of how a session ended  | [Preparing a Session](sessions.md#load-list-or-snapshot) |
| run the table                                | [GM Guide](gm-guide.md)                   |
| deploy the server                            | [Installation](installation.md)           |

## Server Setup

- [Installation](installation.md) --- Docker or a release tarball, environment
  variables, reverse proxy

## Additional Resources

- **Test fixtures** --- `test/data/sessions/` holds working examples you can
  copy and modify: `standard/` is two maps, two tokens and a wallpaper, and
  `party/` is the tokens two characters use. These are the project's own test
  data, so they are examples that load. The characters themselves are declared
  in `test/support/helpers.ex`, because a character is a few fields and no
  bytes and has no file of its own.
- **The API** --- `GET /api/openapi.json` from a running server. The document
  is hand-written and authoritative; the server refuses to boot if its routes
  and the document disagree.
