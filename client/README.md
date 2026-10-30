# PathMapper client

The other half of PathMapper. The server holds nothing of its own --- maps,
tokens, characters and the sessions they make up live on the game master's
machine, and this program sends them over when a session needs them.

It is not a library the server shares. It is a program the desktop runs.

**The documentation lives in [`docs/`](../docs/), with the rest of PathMapper's:**

- [The Client](../docs/client.md) --- install, configuration, the library, and
  everything this program does
- [Preparing a Session](../docs/sessions.md) --- composing a session, writing
  it down as a `.pmload`, and loading it again next week
- [Documentation index](../docs/README.md) --- maps, tokens, characters, the GM
  guide

## Install

```sh
bundle install
ln -s "$PWD/bin/path-mapper" ~/.local/bin/path-mapper
./desktop/install.sh
```

Then write `~/.config/pathmapper/config.toml`. See
[The Client](../docs/client.md) for what goes in it.

## Working on it

```sh
bundle exec rake test     # minitest
bundle exec rubocop       # lint
```

Both must pass. The suite reads the same fixtures the Elixir suite does, from
`test/data/`, so the two implementations of the pipeline are held to one oracle
rather than two.

Two runtime dependencies, `rubyzip` and `toml-rb`. GIMP and Emacs are invoked
headless where a `.xcf` or an org `.pmcharacter` needs reading, and the tests
stub both --- neither is required to run them.

## Layout

```
bin/path-mapper      # argv in, an exit status out
lib/path_mapper/     # one file per concern; cli.rb is the entry point
desktop/             # .desktop entries, MIME types, install.sh
test/                # minitest, mirroring lib/
```
