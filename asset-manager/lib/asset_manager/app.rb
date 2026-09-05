# frozen_string_literal: true

require 'gtk3'
require_relative 'scanner'
require_relative 'index'
require_relative 'thumbnail_cache'
require_relative 'gimp_bridge'
require_relative 'preview_panel'
require_relative 'directory_tree_builder'
require_relative 'asset_grid'
require_relative 'filter_bar'

module AssetManager
  class App
    SEARCH_DEBOUNCE_MS = 300

    def initialize(asset_root)
      @asset_root = File.expand_path(asset_root)
      @search_timeout_id = nil
      @current_directory = nil
      @search_generation = 0
    end

    def run
      @thumbs = ThumbnailCache.new(@asset_root)
      @gimp = RealGimpBridge.new(on_error: method(:report_gimp_error))

      build_ui
      update_status('Scanning assets...')

      Thread.new do
        assets = Scanner.scan(@asset_root)
        index = Index.new(assets)
        GLib::Idle.add do
          @index = index
          DirectoryTreeBuilder.populate(@dir_store, @index.all_directories)
          update_status("Ready — #{assets.size} assets in #{@index.all_directories.size} directories")
          false
        end
      end

      Gtk.main
    end

    private

    def build_ui
      @window = Gtk::Window.new('Asset Manager')
      @window.set_default_size(1200, 700)
      @window.signal_connect('destroy') { Gtk.main_quit }

      main_box = Gtk::Box.new(:vertical, 0)
      build_search_bar(main_box)
      @filter_bar = FilterBar.new(on_changed: method(:refresh_grid))
      main_box.pack_start(@filter_bar.widget, expand: false, fill: false, padding: 0)
      build_main_layout(main_box)
      build_status_bar(main_box)

      @window.add(main_box)
      @window.show_all
    end

    def build_search_bar(parent)
      @search_entry = Gtk::SearchEntry.new
      @search_entry.placeholder_text = 'Search assets by tags...'
      @search_entry.signal_connect('search-changed') { on_search_changed }
      parent.pack_start(@search_entry, expand: false, fill: true, padding: 4)
    end

    def build_main_layout(parent)
      hpaned = Gtk::Paned.new(:horizontal)

      dir_scroll = Gtk::ScrolledWindow.new
      dir_scroll.set_policy(:automatic, :automatic)
      dir_scroll.width_request = 250
      dir_scroll.add(build_directory_tree)
      hpaned.pack1(dir_scroll, resize: false, shrink: false)

      rpaned = Gtk::Paned.new(:horizontal)
      grid_scroll = Gtk::ScrolledWindow.new
      grid_scroll.set_policy(:automatic, :automatic)
      @grid = AssetGrid.new(@thumbs, on_select: method(:on_asset_selected))
      grid_scroll.add(@grid.widget)
      rpaned.pack1(grid_scroll, resize: true, shrink: false)

      @preview = PreviewPanel.new(@thumbs, @gimp, method(:update_status),
                                  on_advance: method(:advance_grid),
                                  on_go_to_directory: method(:navigate_to_directory))
      rpaned.pack2(@preview.widget, resize: false, shrink: false)
      rpaned.position = 600

      hpaned.pack2(rpaned, resize: true, shrink: false)
      hpaned.position = 250

      parent.pack_start(hpaned, expand: true, fill: true, padding: 0)
    end

    def build_status_bar(parent)
      @status_bar = Gtk::Label.new('Select a directory to browse assets')
      @status_bar.xalign = 0
      parent.pack_start(@status_bar, expand: false, fill: true, padding: 4)
    end

    def build_directory_tree
      @dir_store = Gtk::TreeStore.new(String, String)

      @dir_tree = Gtk::TreeView.new(@dir_store)
      @dir_tree.headers_visible = false
      renderer = Gtk::CellRendererText.new
      @dir_tree.append_column(Gtk::TreeViewColumn.new('Directory', renderer, text: 0))
      @dir_tree.selection.mode = :single
      @dir_tree.signal_connect('cursor-changed') { on_directory_selected(@dir_tree) }
      @dir_tree.signal_connect('button-press-event') { |w, e| on_tree_click(w, e) }
      @dir_tree
    end

    # --- Event handlers ---

    def on_directory_selected(tree)
      selection = tree.selection
      new_dir = selection.selected && selection.selected[1]
      @filter_bar.clear if new_dir != @current_directory
      @current_directory = new_dir
      refresh_grid
    end

    def on_search_changed
      GLib::Source.remove(@search_timeout_id) if @search_timeout_id
      @search_timeout_id = GLib::Timeout.add(SEARCH_DEBOUNCE_MS) do
        @search_timeout_id = nil
        refresh_grid
        GLib::Source::REMOVE
      end
    end

    def on_asset_selected(asset)
      @preview.show_asset(asset)
    end

    def on_tree_click(widget, event)
      path_info = widget.get_path_at_pos(event.x.to_i, event.y.to_i)
      if path_info && widget.selection.selected&.path == path_info[0]
        widget.selection.unselect_all
        @current_directory = nil
        refresh_grid
      end
      false
    end

    # --- Search orchestration ---

    def refresh_grid
      return unless @index

      query = @search_entry.text
      @grid.clear
      @search_generation += 1
      generation = @search_generation
      update_status('Searching...')

      Thread.new do
        assets = run_search(query)
        GLib::Idle.add do
          show_results(assets, generation)
          false
        end
      end
    end

    def run_search(query)
      assets = if @current_directory
                 @index.search_in_subtree(query, @current_directory)
               elsif query && !query.strip.empty?
                 @index.search(query)
               else
                 []
               end

      if @current_directory
        assets = @index.filter_by_categories(assets, @current_directory, @filter_bar.active_categories)
      end
      @index.filter_by_tags(assets, @filter_bar.active_tags)
    end

    def show_results(assets, generation)
      return unless generation == @search_generation

      @grid.display(assets)
      update_status(@grid.status_text(assets.size))
      update_filter_bar(assets)
    end

    def update_filter_bar(assets)
      if @current_directory
        subtree_assets = @index.filter_by_subtree(@current_directory)
        @filter_bar.update_categories(@index.child_categories(@current_directory, subtree_assets))
      else
        @filter_bar.update_categories([])
      end
      @filter_bar.update_available_tags(@index.available_tags(assets))
    end

    def advance_grid
      @grid.select_next
    end

    def navigate_to_directory(directory)
      @filter_bar.clear
      @current_directory = directory
      select_tree_directory(directory)
      refresh_grid
    end

    def select_tree_directory(directory)
      @dir_store.each do |_model, path, iter|
        next unless iter[1] == directory

        @dir_tree.expand_to_path(path)
        @dir_tree.selection.select_path(path)
        @dir_tree.scroll_to_cell(path, nil, true, 0.5, 0)
        break
      end
    end

    def report_gimp_error(message)
      GLib::Idle.add do
        update_status(message)
        false
      end
    end

    def update_status(text)
      @status_bar.text = text
    end
  end
end
