#!/bin/sh
# Registers the .pm* types, the five entries, the icon and the map template, for
# this user only.
#
# The Exec lines name "path-mapper" with no path, so put the client on PATH - a
# symlink into ~/.local/bin is enough. Nothing here needs root, and no entry
# carries a token: a command line is readable by anyone who can list processes.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
applications="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
configuration="${XDG_CONFIG_HOME:-$HOME/.config}"

# xdg-mime default writes mimeapps.list here and does not create the directory
# itself. Without it the types install, no default handler is set, and the script
# still succeeds - which looks exactly like the association not taking.
mkdir -p "$applications" "$configuration"

# The filename needs a vendor prefix - alpha characters then a dash - or xdg-mime
# refuses it. The prefix is there so two packages cannot collide on one MIME file,
# which is worth having rather than passing --novendor to silence.
xdg-mime install --mode user "$here/pathmapper-types.xml"

# PathMapper lists image/x-xcf so a map can be offered to it, and must not become
# the handler for one: double-clicking a .xcf opens GIMP, because editing a map is
# the commoner thing to want. Leaving xcf out of the default loop below is not
# enough - listing a type at all writes this entry into the user's mimeinfo.cache,
# and that wins the default query wherever nothing else has claimed the type. So
# the previous answer is captured here and put back afterwards.
xcf_was=$(xdg-mime query default image/x-xcf 2>/dev/null || true)

for entry in pathmapper-upload pathmapper-snapshot pathmapper-reset \
             pathmapper-map-new pathmapper-map-upload; do
  cp "$here/$entry.desktop" "$applications/$entry.desktop"
done

# 256 because that is a size hicolor's index.theme enumerates - xdg-icon-resource
# will install a directory for any size asked of it, and a lookup will not find
# one the theme does not list.
xdg-icon-resource install --novendor --size 256 "$here/logo.png" pathmapper

update-desktop-database "$applications" 2>/dev/null || true

# The template is the one file `path-mapper map new` cannot conjure, so it is
# seeded where the default library looks for it. Only when nothing is there:
# re-running this after an update is the normal way to pick up a new entry, and
# it must not overwrite a template the game master has made their own.
library="${XDG_DATA_HOME:-$HOME/.local/share}/path-mapper/maps"
if [ ! -e "$library/template.xcf" ] && [ -f "$here/../../docs/template.xcf" ]; then
  mkdir -p "$library"
  cp "$here/../../docs/template.xcf" "$library/template.xcf"
  echo "Map template installed at $library/template.xcf"
fi

for type in token character map wallpaper load snapshot; do
  xdg-mime default pathmapper-upload.desktop "application/x-pathmapper-$type"
done

xcf_now=$(xdg-mime query default image/x-xcf 2>/dev/null || true)
if [ "$xcf_now" = "pathmapper-upload.desktop" ]; then
  if [ -n "$xcf_was" ] && [ "$xcf_was" != "pathmapper-upload.desktop" ]; then
    xdg-mime default "$xcf_was" image/x-xcf
  else
    echo "Note: nothing claimed .xcf before now, so PathMapper answers for it."
    echo "Point it at your editor:  xdg-mime default gimp.desktop image/x-xcf"
  fi
fi

echo "Installed. Double-click a .pm* file, or run: path-mapper snapshot"
echo "A .xcf map uploads with: path-mapper <file>.xcf"
echo "A map made mid-session: New PathMapper map, draw, save, Upload the new PathMapper map"
