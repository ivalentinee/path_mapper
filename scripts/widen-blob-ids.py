#!/usr/bin/env python3
"""Widen a blob's ids to the current format.

Reads a blob, writes a widened copy. Never touches the original.

  widen-blob-ids.py <in.zip> [out-dir]

  [a-z]{2}\\d{2}-\\d{6}   ->  [a-z]{2}\\d{4}-\\d{10}
  tt01-000001            ->  tt0001-0000000001

Ids live in three places and all three are rewritten: the blob's own filename, the
names of the entries inside it, and the manifest lines that reference them. Only
.toml entries are rewritten as text; everything else is copied byte for byte, so
images and ORA files pass through untouched.

The widening is value-preserving - the same number, more room - so a blob widened
here is the blob it was. It exists to save re-deriving everything through adventurer
for what is a change of width.
"""
import os
import re
import sys
import zipfile

OLD = re.compile(r'([a-z]{2})([0-9]{2})-([0-9]{6})')
OLD_BYTES = re.compile(rb'([a-z]{2})([0-9]{2})-([0-9]{6})')

SERIES_DIGITS = 4
ENTITY_DIGITS = 10


def widen(text):
    return OLD.sub(
        lambda m: m.group(1) + m.group(2).zfill(SERIES_DIGITS) + '-' + m.group(3).zfill(ENTITY_DIGITS),
        text,
    )


def widen_bytes(data):
    return OLD_BYTES.sub(
        lambda m: m.group(1) + m.group(2).rjust(SERIES_DIGITS, b'0') + b'-' + m.group(3).rjust(ENTITY_DIGITS, b'0'),
        data,
    )


def main(argv):
    if not 2 <= len(argv) <= 3:
        sys.exit(__doc__)

    source = argv[1]
    out_dir = argv[2] if len(argv) == 3 else os.path.dirname(source) or '.'
    target = os.path.join(out_dir, widen(os.path.basename(source)))

    if os.path.abspath(target) == os.path.abspath(source):
        sys.exit(f"{source} has no old-format ids to widen")

    os.makedirs(out_dir, exist_ok=True)

    with zipfile.ZipFile(source) as src, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as dst:
        for item in src.infolist():
            data = src.read(item.filename)
            if item.filename.endswith('.toml'):
                data = widen_bytes(data)
            dst.writestr(widen(item.filename), data)

    print(target)


if __name__ == '__main__':
    main(sys.argv)
