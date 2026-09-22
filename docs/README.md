# Path Mapper Documentation

Path Mapper is a lightweight, playback-only Virtual Tabletop (VTT) for Pathfinder
2e and other square-grid TTRPGs. All content --- adventures, groups, maps and
tokens --- is authored externally with text editors and GIMP, packaged into ZIP
files, and uploaded into a running session by the
[client](../client/README.md).

The server holds nothing of its own. There is no library and no content
directory: what a session contains is what a client has put there, and a restart
leaves an empty board.

## Reading Order

If you are new to Path Mapper, read these documents in order:

1. [Quick Start](quick-start.md) --- create your first adventure and group, build ZIPs, and run a session
2. [Groups](groups.md) --- complete reference for creating player groups
3. [Maps](maps.md) --- map construction with GIMP and the ORA layer naming convention
4. [Tokens](tokens.md) --- token images, the PNG keys they may carry, and placements
5. [Adventures](adventures.md) --- complete reference for creating adventures
6. [GM Guide](gm-guide.md) --- running a game session (includes "What your players see")

## Loading and Changing a Session

- [The client](../client/README.md) --- what uploads an adventure, a group, a map,
  a token or a snapshot, and how each is added, replaced or removed

## Server Setup

- [Installation](installation.md) --- deploy with Docker or a release tarball, environment variables, reverse proxy

## Additional Resources

- **Test fixtures** --- `test/data/adventures/unpacked/` and `test/data/groups/unpacked/` contain working examples you can copy and modify
- **Emacs adventurer module** --- optional convenience for editing manifests
  (separate project). `help/` in this repository carries the handoff describing
  what PathMapper currently expects of it.
