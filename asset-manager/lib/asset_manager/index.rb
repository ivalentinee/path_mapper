# frozen_string_literal: true

module AssetManager
  class Index
    attr_reader :assets

    def initialize(assets)
      @assets = assets
      @by_directory = assets.group_by(&:directory)
      @directories = assets.map(&:directory).uniq.sort
    end

    def search(query)
      return assets if query.nil? || query.strip.empty?

      terms = query.strip.downcase.split(/\s+/)
      results = assets.select do |asset|
        terms.all? { |term| asset.tags.any? { |tag| tag.include?(term) } }
      end
      rank_results(results, terms)
    end

    def filter_by_directory(dir)
      @by_directory[dir] || []
    end

    def filter_by_subtree(dir)
      prefix = "#{dir}/"
      assets.select { |a| a.directory == dir || a.directory.start_with?(prefix) }
    end

    def search_in_subtree(query, dir)
      subset = filter_by_subtree(dir)
      return subset if query.nil? || query.strip.empty?

      terms = query.strip.downcase.split(/\s+/)
      results = subset.select do |asset|
        terms.all? { |term| asset.tags.any? { |tag| tag.include?(term) } }
      end
      rank_results(results, terms)
    end

    def search_in_directory(query, dir)
      subset = filter_by_directory(dir)
      return subset if query.nil? || query.strip.empty?

      terms = query.strip.downcase.split(/\s+/)
      subset.select do |asset|
        terms.all? { |term| asset.tags.any? { |tag| tag.include?(term) } }
      end
    end

    def all_directories
      @directories
    end

    def in_directory(dir)
      (filter_by_directory(dir) || []).sort_by(&:filename)
    end

    def child_categories(subtree_dir, asset_set)
      prefix = "#{subtree_dir}/"
      asset_set
        .filter_map { |a| a.directory.delete_prefix(prefix).split('/').first if a.directory.start_with?(prefix) }
        .tally
        .sort_by { |_, count| -count }
        .map(&:first)
    end

    def filter_by_categories(asset_set, subtree_dir, categories)
      return asset_set if categories.empty?

      prefix = "#{subtree_dir}/"
      asset_set.select do |a|
        child = a.directory.delete_prefix(prefix).split('/').first if a.directory.start_with?(prefix)
        child && categories.include?(child)
      end
    end

    def filter_by_tags(asset_set, tags)
      return asset_set if tags.empty?

      asset_set.select do |a|
        tags.all? { |t| a.tags.include?(t) }
      end
    end

    def available_tags(asset_set, limit: 15)
      variant_pattern = /\A[a-z]\d*\z/
      tag_counts = Hash.new(0)
      asset_set.each { |a| a.tags.each { |t| tag_counts[t] += 1 unless t.match?(variant_pattern) } }
      tag_counts.sort_by { |_, v| -v }.first(limit).map(&:first)
    end

    private

    def rank_results(results, terms)
      results.sort_by do |asset|
        # Count how many terms have a tag starting with them (prefix match)
        prefix_matches = terms.count { |t| asset.tags.any? { |tag| tag.start_with?(t) } }
        [-prefix_matches, asset.filename]
      end
    end
  end
end
