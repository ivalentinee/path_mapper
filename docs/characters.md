# Characters

A character is someone in the game: a name, a colour, the token they go down
as, and whatever markings they may place. It is the one piece that is not an
image, so it is the one piece declared in a file you write rather than export.

Characters live in a `.pmcharacter` file, which may be written three ways ---
**org**, **TOML** or **JSON**. The client tells them apart by looking at the
file, not at its name. Several characters may share one file.

## What a character is made of

| Field            | Meaning                                              |
|------------------|------------------------------------------------------|
| id               | Two letters, four digits, a dash, ten digits.         |
| character name   | What the table calls them.                            |
| player name      | Who is playing them. For your convenience; nothing reads it. |
| class            | Free text.                                            |
| colour           | What their marks are drawn in.                        |
| token            | The token they go down as. **Required.**              |
| extras           | Markings they may place, as often as they like.       |
| charkeeper id    | Optional, for the character-sheet integration.        |

**A character carries its own id.** Every other piece takes its id from its
filename; a character does not, because one file may declare several and
because there are no bytes for the server to address.

## Pointing at a token

A character names its tokens, and there are two ways to do it.

- **By path** --- the file at that path is used, relative to the character file.
- **By id** --- the token is looked up in your [library](client.md#where-it-keeps-things).

Either way, **the file still carries the id in its name**:
`tk0002-0000000001-valeros.pmtoken`.

**The character names and owns the tokens it points at.** Whatever a token's own
PNG says about its name and owner, a character pointing at it wins --- the
token's bytes cannot know which character is using them.

**A character with no token, or whose token is nowhere, is refused.** A missing
extra is not: you are told, and the character goes without it.

## org

The shape is one level-one headline per character, with a property drawer. The
headline is the character's name.

```org
* Valeros
:PROPERTIES:
:ID:     pg0001-0000000001
:CLASS:  Fighter
:PLAYER: Johnny
:COLOR:  #328546
:TOKEN:  [[file:assets/tk0002-0000000001-valeros.pmtoken][Valeros]]
:EXTRA:  [[tk0002-0000000002][Bloodied]]
:END:
```

A `file:` link is a path; a bare one is an id. The link's description is what
the token will be called.

Reading org needs **Emacs** on the machine running the client --- it is the only
thing that reads org correctly, and it is where your file came from. Nothing of
PathMapper's is installed into it. A character written in TOML or JSON needs no
Emacs.

Anything in the file that is not a level-one character is refused rather than
skipped, so a mistyped id is reported instead of quietly producing nobody.

## TOML

```toml
id = "pg0001-0000000001"
character_name = "Valeros"
class = "Fighter"
player_name = "Johnny"
color = "#328546"
token = "assets/tk0002-0000000001-valeros.pmtoken"
token_name = "Valeros"

[[extras]]
target = "tk0002-0000000002"
name = "Bloodied"
```

A value that is id-shaped is an id; anything else is a path. For several
characters in one file, use `[[characters]]` tables.

## JSON

```json
{
  "id": "pg0001-0000000001",
  "character_name": "Valeros",
  "class": "Fighter",
  "player_name": "Johnny",
  "color": "#328546",
  "token": "assets/tk0002-0000000001-valeros.pmtoken",
  "token_name": "Valeros",
  "extras": [{ "target": "tk0002-0000000002", "name": "Bloodied" }]
}
```

A top-level array is several characters.

## Uploading

```sh
path-mapper the-party.pmcharacter
```

The tokens go up with the characters that name them. A character is sent once
its own references resolve, so a file whose third character is broken sends the
first two and tells you which one it could not.
