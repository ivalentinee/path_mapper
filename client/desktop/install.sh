#!/bin/sh
# Registers the .pm* types and the three entries, for this user only.
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

for entry in pathmapper-upload pathmapper-snapshot pathmapper-reset; do
  cp "$here/$entry.desktop" "$applications/$entry.desktop"
done

update-desktop-database "$applications" 2>/dev/null || true

for type in adventure group token map snapshot; do
  xdg-mime default pathmapper-upload.desktop "application/x-pathmapper-$type"
done

echo "Installed. Double-click a .pm* file, or run: path-mapper snapshot"
