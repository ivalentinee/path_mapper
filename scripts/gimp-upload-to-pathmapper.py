#!/usr/bin/env python3
"""
GIMP 3.2+ Plugin: Upload to Path Mapper

Exports the current image as ORA and uploads it to a running
Path Mapper instance via the /api/scenes/map endpoint.

Installation:
  Copy this file to ~/.config/GIMP/3.0/plug-ins/gimp-upload-to-pathmapper/
  (create the directory, make the file executable)

Configuration:
  Edit SERVER_URL and UPLOAD_TOKEN below.

Usage:
  File → Upload to Path Mapper
  Bind a keyboard shortcut via Edit → Keyboard Shortcuts
"""

import gi
gi.require_version('Gimp', '3.0')
gi.require_version('GimpUi', '3.0')
from gi.repository import Gimp, GimpUi, GObject, GLib, Gio
import json
import os
import sys
import tempfile
import urllib.request
import urllib.error

# --- Configuration ---
SERVER_URL = "http://localhost:4000"
UPLOAD_TOKEN = "dev-upload-token"


def upload_to_pathmapper(procedure, run_mode, image, *args):
    """Main plugin procedure."""
    # Export as ORA to a temp file
    tmp_fd, tmp_path = tempfile.mkstemp(suffix='.ora')
    os.close(tmp_fd)

    try:
        # Save as ORA
        file = Gio.File.new_for_path(tmp_path)
        Gimp.file_save(Gimp.RunMode.NONINTERACTIVE, image, file)

        # Read the ORA file
        with open(tmp_path, 'rb') as f:
            ora_data = f.read()

        # Build multipart/form-data request
        boundary = '----PythonFormBoundary'
        body = (
            f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="file"; filename="map.ora"\r\n'
            f'Content-Type: application/octet-stream\r\n\r\n'
        ).encode('utf-8') + ora_data + f'\r\n--{boundary}--\r\n'.encode('utf-8')

        url = f'{SERVER_URL}/api/scenes/map'
        req = urllib.request.Request(
            url,
            data=body,
            headers={
                'Content-Type': f'multipart/form-data; boundary={boundary}',
                'Authorization': f'Bearer {UPLOAD_TOKEN}',
                'Accept': 'application/json',
            },
            method='POST',
        )

        response = urllib.request.urlopen(req, timeout=30)
        result = json.loads(response.read().decode('utf-8'))

        if result.get('status') == 'ok':
            Gimp.message('Map uploaded successfully!')
        else:
            Gimp.message(f'Upload response: {result}')

    except urllib.error.HTTPError as e:
        try:
            error_body = json.loads(e.read().decode('utf-8'))
            msg = error_body.get('error', str(e))
        except Exception:
            msg = str(e)
        Gimp.message(f'Upload failed: {msg}')

    except urllib.error.URLError as e:
        Gimp.message(f'Cannot connect to Path Mapper at {SERVER_URL}: {e.reason}')

    except Exception as e:
        Gimp.message(f'Upload error: {e}')

    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    return procedure.new_return_values(Gimp.PDBStatusType.SUCCESS, GLib.Error())


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
            'Upload current image as ORA to Path Mapper',
            'Exports the image as OpenRaster and uploads it to the active scene in Path Mapper',
            name,
        )
        procedure.set_attribution(
            'Path Mapper',
            'Path Mapper',
            '2026',
        )
        return procedure


Gimp.main(UploadToPathMapper.__gtype__, sys.argv)
