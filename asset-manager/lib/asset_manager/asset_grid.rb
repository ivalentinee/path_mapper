# frozen_string_literal: true

module AssetManager
  class AssetGrid
    MAX_DISPLAY = 500
    THUMB_BATCH_SIZE = 20

    attr_reader :widget, :displayed_assets

    def initialize(thumbnail_cache, on_select:)
      @thumbs = thumbnail_cache
      @on_select = on_select
      @displayed_assets = []
      @display_generation = 0
      @store = Gtk::ListStore.new(GdkPixbuf::Pixbuf, String, Integer)
      @widget = build
    end

    def display(assets)
      @store.clear
      @display_generation += 1
      generation = @display_generation
      @displayed_assets = assets.first(MAX_DISPLAY)

      Thread.new do
        batch = []
        @displayed_assets.each_with_index do |asset, idx|
          break unless generation == @display_generation

          pixbuf = @thumbs.get_pixbuf(asset)
          next unless pixbuf

          batch << [pixbuf, asset.filename, idx]

          next unless batch.size >= THUMB_BATCH_SIZE

          post_batch(batch.dup, generation)
          batch.clear
        end
        post_batch(batch, generation) unless batch.empty?
      end

      @displayed_assets
    end

    def clear
      @store.clear
      @display_generation += 1
      @displayed_assets = []
    end

    def select_next
      selected = @icon_view.selected_items
      return if selected.empty? || @displayed_assets.empty?

      current_idx = @store.get_iter(selected.first)[2]
      next_idx = (current_idx + 1) % @displayed_assets.size

      # Find the TreePath for the next index by iterating the store
      @store.each do |_model, path, iter|
        next unless iter[2] == next_idx

        @icon_view.unselect_all
        @icon_view.select_path(path)
        @icon_view.scroll_to_path(path, false, 0, 0)
        break
      end
    end

    def status_text(total_count)
      return "Showing #{MAX_DISPLAY} of #{total_count} assets" if total_count > MAX_DISPLAY
      return 'No assets found' if total_count.zero?

      "#{total_count} assets"
    end

    private

    def build
      @icon_view = Gtk::IconView.new(model: @store)
      @icon_view.pixbuf_column = 0
      @icon_view.text_column = 1
      @icon_view.item_width = 80
      @icon_view.column_spacing = 4
      @icon_view.row_spacing = 4
      @icon_view.signal_connect('selection-changed') { on_selection_changed(@icon_view) }
      @icon_view
    end

    def on_selection_changed(icon_view)
      selected = icon_view.selected_items
      unless selected.any?
        @on_select.call(nil)
        return
      end

      iter = @store.get_iter(selected.first)
      return unless iter

      asset = @displayed_assets[iter[2]]
      @on_select.call(asset)
    end

    def post_batch(batch, generation)
      GLib::Idle.add do
        if generation == @display_generation
          batch.each do |pixbuf, filename, idx|
            iter = @store.append
            iter[0] = pixbuf
            iter[1] = truncate(filename, 12)
            iter[2] = idx
          end
        end
        false
      end
    end

    def truncate(text, max_len)
      text.length > max_len ? "#{text[0, max_len]}…" : text
    end
  end
end
