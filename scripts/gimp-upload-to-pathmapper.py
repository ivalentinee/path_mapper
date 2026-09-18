#!/usr/bin/env python3
"""
GIMP 3.2+ Plugin: Upload to Path Mapper

Exports the current image as a .pmmap and hands it to the PathMapper client,
which is the only thing that speaks to the server. The plug-in holds no server
address and no token: those live in the client's own configuration, so there is
one place to change them and no credential in this repository.

Exporting to .pmmap rather than .ora is deliberate - it makes this path identical
to opening the same file from a file manager, so there is one way a map reaches
the server rather than two.

Installation:
  Copy this file to ~/.config/GIMP/3.0/plug-ins/gimp-upload-to-pathmapper/
  (create the directory, make the file executable)

Configuration:
  Set PATH_MAPPER_CLIENT_PATH below to wherever the client is installed. It is
  named outright rather than searched for on PATH, because a GIMP plug-in can run
  with an environment that has almost nothing in it.

Usage:
  File -> Upload to Path Mapper
  Bind a keyboard shortcut via Edit -> Keyboard Shortcuts
"""

import gi
gi.require_version('Gimp', '3.0')
gi.require_version('GimpUi', '3.0')
from gi.repository import Gimp, GimpUi, GObject, GLib, Gio
import os
import subprocess
import sys
import tempfile

# --- Configuration ---
PATH_MAPPER_CLIENT_PATH = os.path.expanduser("~/path-mapper/client/bin/path-mapper")

TIMEOUT_SECONDS = 120


def upload_to_pathmapper(procedure, run_mode, image, *args):
    """Export the image and hand it to the client."""
    if not os.path.exists(PATH_MAPPER_CLIENT_PATH):
        Gimp.message(
            "PathMapper client not found at %s.\n\n"
            "Install it, or edit PATH_MAPPER_CLIENT_PATH in this plug-in."
            % PATH_MAPPER_CLIENT_PATH
        )
        return procedure.new_return_values(Gimp.PDBStatusType.EXECUTION_ERROR, GLib.Error())

    # GIMP chooses the export format from the extension, and .pmmap is not one it
    # knows - so the export is an .ora and the rename gives it the name the client
    # dispatches on.
    tmp_fd, ora_path = tempfile.mkstemp(suffix='.ora')
    os.close(tmp_fd)
    tmp_path = ora_path[:-len('.ora')] + '.pmmap'

    try:
        Gimp.file_save(Gimp.RunMode.NONINTERACTIVE, image, Gio.File.new_for_path(ora_path))
        os.replace(ora_path, tmp_path)

        # Synchronous: the temporary file has to outlive the upload, and there is
        # nothing useful to do while it runs.
        result = subprocess.run(
            [PATH_MAPPER_CLIENT_PATH, tmp_path],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS,
        )

        if result.returncode == 0:
            Gimp.message("Map uploaded to Path Mapper")
            status = Gimp.PDBStatusType.SUCCESS
        else:
            # The client decides how a failure reads, so it is shown verbatim.
            Gimp.message(result.stderr.strip() or "Upload failed with no message")
            status = Gimp.PDBStatusType.EXECUTION_ERROR

    except subprocess.TimeoutExpired:
        Gimp.message("Upload timed out after %d seconds" % TIMEOUT_SECONDS)
        status = Gimp.PDBStatusType.EXECUTION_ERROR
    except Exception as error:
        Gimp.message("Upload failed: %s" % error)
        status = Gimp.PDBStatusType.EXECUTION_ERROR
    finally:
        for path in (ora_path, tmp_path):
            try:
                os.unlink(path)
            except OSError:
                pass

    return procedure.new_return_values(status, GLib.Error())


class UploadToPathMapper(Gimp.PlugIn):
    """GIMP 3.2+ plugin registration."""

    def do_query_procedures(self):
        return ['upload-to-pathmapper']

    def do_set_i18n(self, name):
        return False

    def do_create_procedure(self, name):
        procedure = Gimp.ImageProcedure.new(
            self,
            name,
            Gimp.PDBProcType.PLUGIN,
            upload_to_pathmapper,
            None,
        )
        procedure.set_menu_label('Upload to Path Mapper')
        procedure.add_menu_path('<Image>/File')
        procedure.set_documentation(
            'Upload the current image to Path Mapper',
            'Exports the image as a .pmmap and hands it to the PathMapper client',
            name,
        )
        procedure.set_attribution(
            'Path Mapper',
            'Path Mapper',
            '2026',
        )
        return procedure


Gimp.main(UploadToPathMapper.__gtype__, sys.argv)
