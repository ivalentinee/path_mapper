#!/bin/bash
# Build a content ZIP from a directory.
#
# Usage: ./scripts/build.sh <directory> [output.zip]
#
# Works for both adventures and groups --- any directory with a
# manifest.toml at its root.
#
# If output name is omitted, uses the directory name + .zip.
#
# Examples:
#   ./scripts/build.sh my-adventure/
#   # produces my-adventure.zip
#
#   ./scripts/build.sh my-group/ party.zip
#   # produces party.zip

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <directory> [output.zip]"
    exit 1
fi

SOURCE_DIR="$1"
OUTPUT="${2:-$(basename "${SOURCE_DIR%/}").zip}"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: directory not found: $SOURCE_DIR"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/manifest.toml" ]; then
    echo "Error: manifest.toml not found in $SOURCE_DIR"
    exit 1
fi

# Remove existing output to avoid appending to old archive
rm -f "$OUTPUT"

(cd "$SOURCE_DIR" && zip -r - .) > "$OUTPUT"

echo "Built: $OUTPUT"
