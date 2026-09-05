# Asset Manager

A desktop asset browser for VTT map building. Browse, search, and send map assets directly to GIMP 3.2+ via Script-Fu.

## Prerequisites

### Debian/Ubuntu

```bash
sudo apt install ruby ruby-dev ruby-bundler rake libgtk-3-dev \
  libgdk-pixbuf2.0-dev gobject-introspection libgirepository1.0-dev build-essential
```

### Fedora

```bash
sudo dnf install ruby ruby-devel gtk3-devel gdk-pixbuf2-devel \
  gobject-introspection-devel gcc make
```

### Arch

```bash
sudo pacman -S ruby gtk3 gdk-pixbuf2 gobject-introspection base-devel
```

## Install

```bash
cd asset-manager
bundle config set --local path 'vendor/bundle'
bundle install
```

## GIMP Setup

The asset manager sends assets to GIMP 3.2+ via the Script-Fu TCP server.

### Start Script-Fu Server (once per GIMP session)

1. Open GIMP
2. Filters → Script-Fu → Start Server
3. Keep the default port (10008) and click OK

The server runs in the background for the rest of the session. The asset manager connects automatically when you click "Load as Pattern" or "Load as Layer".

### Usage

- **Load as Pattern**: sends the asset as GIMP's "Clipboard Image" pattern. Use with the Clone tool (pattern source) or Bucket Fill (pattern fill) to paint textures.
- **Load as Layer**: inserts the asset as a new layer in the current image. Use for placing individual objects (furniture, trees, props).
- **Scale slider**: adjusts the asset size before sending (0.1x–2.0x).

## Run

```bash
ruby bin/asset-manager /path/to/your/map-assets
```

## Test

```bash
bundle exec rake test
```
