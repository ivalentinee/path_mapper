# frozen_string_literal: true

module AssetManager
  class FilterBar
    MAX_CATEGORIES_VISIBLE = 8
    MAX_TAGS_VISIBLE = 15

    attr_reader :widget, :active_categories, :active_tags

    def initialize(on_changed:)
      @on_changed = on_changed
      @active_categories = []
      @active_tags = []
      @all_categories = []
      @all_available_tags = []
      @widget = build
    end

    def update_categories(categories)
      @all_categories = categories
      @active_categories.select! { |c| categories.include?(c) }
      rebuild_category_row
    end

    def update_available_tags(tags)
      @all_available_tags = tags - @active_tags
      rebuild_available_tags_row
    end

    def clear
      @active_categories.clear
      @active_tags.clear
      @all_categories = []
      @all_available_tags = []
      rebuild_category_row
      rebuild_active_tags_row
      rebuild_available_tags_row
    end

    private

    def build
      @container = Gtk::Box.new(:vertical, 2)
      @container.margin_start = 4
      @container.margin_end = 4

      @category_row = Gtk::FlowBox.new
      @category_row.selection_mode = :none
      @category_row.max_children_per_line = 20
      @container.pack_start(@category_row, expand: false, fill: false, padding: 0)

      @active_tags_row = Gtk::FlowBox.new
      @active_tags_row.selection_mode = :none
      @active_tags_row.max_children_per_line = 20
      @container.pack_start(@active_tags_row, expand: false, fill: false, padding: 0)

      @available_tags_row = Gtk::FlowBox.new
      @available_tags_row.selection_mode = :none
      @available_tags_row.max_children_per_line = 20
      @container.pack_start(@available_tags_row, expand: false, fill: false, padding: 0)

      @container
    end

    def rebuild_category_row
      clear_flow_box(@category_row)
      visible = @all_categories.first(MAX_CATEGORIES_VISIBLE)
      remaining = @all_categories.size - visible.size

      visible.each do |cat|
        btn = Gtk::ToggleButton.new(label: cat.tr('_', ' '))
        btn.active = @active_categories.include?(cat)
        btn.signal_connect('toggled') { on_category_toggled(cat, btn.active?) }
        @category_row.add(btn)
      end

      if remaining.positive?
        label = Gtk::Label.new("+#{remaining} more")
        @category_row.add(label)
      end

      @category_row.show_all
    end

    def rebuild_active_tags_row
      clear_flow_box(@active_tags_row)

      @active_tags.each do |tag|
        btn = Gtk::Button.new(label: "#{tag} ×")
        btn.signal_connect('clicked') { remove_tag(tag) }
        @active_tags_row.add(btn)
      end

      @active_tags_row.show_all
    end

    def rebuild_available_tags_row
      clear_flow_box(@available_tags_row)

      @all_available_tags.first(MAX_TAGS_VISIBLE).each do |tag|
        btn = Gtk::Button.new(label: tag)
        btn.relief = :none
        btn.signal_connect('clicked') { add_tag(tag) }
        @available_tags_row.add(btn)
      end

      @available_tags_row.show_all
    end

    def on_category_toggled(category, now_active)
      if now_active
        @active_categories << category unless @active_categories.include?(category)
      else
        @active_categories.delete(category)
      end
      @on_changed.call
    end

    def add_tag(tag)
      @active_tags << tag unless @active_tags.include?(tag)
      rebuild_active_tags_row
      @on_changed.call
    end

    def remove_tag(tag)
      @active_tags.delete(tag)
      rebuild_active_tags_row
      @on_changed.call
    end

    def clear_flow_box(flow_box)
      flow_box.each { |child| flow_box.remove(child) }
    end
  end
end
