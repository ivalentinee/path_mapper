# frozen_string_literal: true

module AssetManager
  class PreviewPanel
    attr_reader :widget, :selected_asset

    def initialize(thumbnail_cache, gimp_bridge, status_callback, on_advance:, on_go_to_directory:)
      @thumbs = thumbnail_cache
      @gimp = gimp_bridge
      @status_callback = status_callback
      @on_advance = on_advance
      @on_go_to_directory = on_go_to_directory
      @selected_asset = nil
      @auto_cycle = false
      @preview_generation = 0
      @widget = build
    end

    def show_asset(asset)
      @selected_asset = asset
      return unless asset

      @preview_generation += 1
      generation = @preview_generation

      # Update text immediately (cheap)
      @preview_name.text = asset.filename
      @preview_tags.text = "Tags: #{asset.tags.join(', ')}"
      grid_str = asset.grid_size ? "#{asset.grid_size[0]}x#{asset.grid_size[1]}" : 'none'
      @preview_size.text = "Grid: #{grid_str}  |  Dir: #{asset.directory}"

      # Load preview image in background
      Thread.new do
        pixbuf = @thumbs.get_preview(asset, size: 256)
        GLib::Idle.add do
          @preview_image.pixbuf = pixbuf if pixbuf && generation == @preview_generation
          false
        end
      end
    end

    def current_scale
      @scale_slider.value.round(1)
    end

    private

    def build
      box = Gtk::Box.new(:vertical, 8)
      box.width_request = 280
      box.margin = 8

      build_preview_image(box)
      build_metadata_labels(box)
      build_scale_slider(box)
      build_image_selector(box)
      build_action_buttons(box)
      build_auto_cycle_toggle(box)

      box
    end

    def build_preview_image(parent)
      @preview_image = Gtk::Image.new
      @preview_image.set_size_request(256, 256)
      parent.pack_start(@preview_image, expand: false, fill: false, padding: 0)
    end

    def build_metadata_labels(parent)
      @preview_name = Gtk::Label.new('')
      @preview_name.wrap = true
      @preview_name.xalign = 0
      parent.pack_start(@preview_name, expand: false, fill: false, padding: 0)

      @preview_tags = Gtk::Label.new('')
      @preview_tags.wrap = true
      @preview_tags.xalign = 0
      @preview_tags.selectable = true
      parent.pack_start(@preview_tags, expand: false, fill: false, padding: 0)

      @preview_size = Gtk::Label.new('')
      @preview_size.xalign = 0
      parent.pack_start(@preview_size, expand: false, fill: false, padding: 0)
    end

    def build_scale_slider(parent)
      scale_box = Gtk::Box.new(:horizontal, 4)
      scale_label = Gtk::Label.new('Scale:')
      scale_box.pack_start(scale_label, expand: false, fill: false, padding: 0)

      @scale_slider = Gtk::Scale.new(:horizontal)
      @scale_slider.set_range(0.1, 2.0)
      @scale_slider.value = 1.0
      @scale_slider.digits = 1
      @scale_slider.set_size_request(150, -1)
      scale_box.pack_start(@scale_slider, expand: true, fill: true, padding: 0)

      @scale_value_label = Gtk::Label.new('1.0x')
      scale_box.pack_start(@scale_value_label, expand: false, fill: false, padding: 0)

      @scale_slider.signal_connect('value-changed') do
        @scale_value_label.text = "#{current_scale}x"
      end

      parent.pack_start(scale_box, expand: false, fill: false, padding: 4)
    end

    def build_image_selector(parent)
      selector_box = Gtk::Box.new(:horizontal, 4)

      label = Gtk::Label.new('Target:')
      selector_box.pack_start(label, expand: false, fill: false, padding: 0)

      @image_combo = Gtk::ComboBoxText.new
      @image_combo.append('0', '(auto — oldest image)')
      @image_combo.active = 0
      @image_ids = [0]
      selector_box.pack_start(@image_combo, expand: true, fill: true, padding: 0)

      refresh_btn = Gtk::Button.new(label: '⟳')
      refresh_btn.signal_connect('clicked') { refresh_image_list }
      selector_box.pack_start(refresh_btn, expand: false, fill: false, padding: 0)

      parent.pack_start(selector_box, expand: false, fill: false, padding: 4)
    end

    def refresh_image_list
      images = @gimp.list_images
      @image_combo.remove_all
      @image_combo.append('0', '(auto — oldest image)')
      @image_ids = [0]

      images.each do |id, name|
        @image_combo.append(id.to_s, "#{id}: #{name}")
        @image_ids << id
      end

      @image_combo.active = 0
    end

    def target_image_id
      idx = @image_combo.active
      return nil if idx.negative?

      @image_ids[idx]
    end

    def build_action_buttons(parent)
      btn_box = Gtk::Box.new(:vertical, 4)

      pattern_btn = Gtk::Button.new(label: 'Load as Pattern')
      pattern_btn.signal_connect('clicked') { on_load_as_pattern }
      btn_box.pack_start(pattern_btn, expand: false, fill: true, padding: 0)

      layer_btn = Gtk::Button.new(label: 'Load as Layer')
      layer_btn.signal_connect('clicked') { on_load_as_layer }
      btn_box.pack_start(layer_btn, expand: false, fill: true, padding: 0)

      parent.pack_start(btn_box, expand: false, fill: false, padding: 4)
    end

    def build_auto_cycle_toggle(parent)
      cycle_box = Gtk::Box.new(:horizontal, 8)

      label = Gtk::Label.new('Auto-cycle')
      cycle_box.pack_start(label, expand: false, fill: false, padding: 0)

      @cycle_switch = Gtk::Switch.new
      @cycle_switch.active = false
      @cycle_switch.signal_connect('state-set') do |_, state|
        @auto_cycle = state
        false
      end
      cycle_box.pack_start(@cycle_switch, expand: false, fill: false, padding: 0)

      parent.pack_start(cycle_box, expand: false, fill: false, padding: 4)

      go_dir_btn = Gtk::Button.new(label: 'Go to directory')
      go_dir_btn.signal_connect('clicked') { on_go_to_directory }
      parent.pack_start(go_dir_btn, expand: false, fill: false, padding: 0)
    end

    def on_go_to_directory
      return unless @selected_asset

      @on_go_to_directory.call(@selected_asset.directory)
    end

    def on_load_as_pattern
      return unless @selected_asset

      asset = @selected_asset
      scale = current_scale
      @status_callback.call("Sending pattern: #{asset.filename}...")
      Thread.new do
        @gimp.load_as_pattern(asset.path, scale: scale)
        GLib::Idle.add do
          @status_callback.call("Pattern loaded: #{asset.filename} @ #{scale}x")
          false
        end
      end
      advance_if_cycling
    end

    def on_load_as_layer
      return unless @selected_asset

      asset = @selected_asset
      image_id = resolve_target_image_id
      return unless image_id

      @status_callback.call("Sending layer: #{asset.filename}...")
      Thread.new do
        @gimp.load_as_layer(asset.path, image_id: image_id)
        GLib::Idle.add do
          @status_callback.call("Layer loaded: #{asset.filename}")
          false
        end
      end
      advance_if_cycling
    end

    def resolve_target_image_id
      selected = target_image_id
      return selected if selected && selected != 0

      # Auto mode: query GIMP, pick oldest (last in list)
      images = @gimp.list_images
      if images.empty?
        @status_callback.call('No images open in GIMP')
        return nil
      end
      images.last[0]
    end

    def advance_if_cycling
      @on_advance.call if @auto_cycle
    end
  end
end
