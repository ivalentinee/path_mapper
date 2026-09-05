# frozen_string_literal: true

require_relative 'test_helper'

class IndexTest < Minitest::Test
  def build_asset(filename, directory: 'Furniture/Tables')
    # Simulate Scanner.parse_asset logic inline
    extname = File.extname(filename)
    bare = File.basename(filename, extname)
    tokens = bare.split('_')
    grid_size = nil
    if tokens.last&.match?(/\A\d+x\d+\z/)
      parts = tokens.pop.split('x')
      grid_size = [parts[0].to_i, parts[1].to_i]
    end

    AssetManager::Asset.new(
      path: "/maps/#{directory}/#{filename}",
      filename: bare,
      directory: directory,
      tags: tokens.map(&:downcase),
      grid_size: grid_size,
      extension: extname.delete_prefix('.').downcase
    )
  end

  def setup
    @assets = [
      build_asset('Table_Round_Wood_Walnut_A_1x1.png'),
      build_asset('Table_Round_Wood_Walnut_B_1x1.png'),
      build_asset('Table_Round_Wood_Dark_A_2x2.png'),
      build_asset('Chair_Wood_Simple_A_1x1.png', directory: 'Furniture/Chairs'),
      build_asset('Brazier_Metal_Black_A1_2x2.png', directory: 'Lightsources/Braziers'),
      build_asset('Grass_Texture_A.jpg', directory: 'Textures/Grass')
    ]
    @index = AssetManager::Index.new(@assets)
  end

  # --- search ---

  def test_search_single_term
    results = @index.search('table')
    assert_equal 3, results.size
  end

  def test_search_multiple_terms_and_semantics
    results = @index.search('table walnut')
    assert_equal 2, results.size
    results.each { |a| assert_includes a.tags, 'walnut' }
  end

  def test_search_substring_match
    results = @index.search('wal')
    assert_equal 2, results.size # walnut
  end

  def test_search_case_insensitive
    results = @index.search('TABLE')
    assert_equal 3, results.size
  end

  def test_search_no_results
    results = @index.search('dragon')
    assert_equal [], results
  end

  def test_search_empty_query_returns_all
    results = @index.search('')
    assert_equal @assets.size, results.size
  end

  def test_search_nil_query_returns_all
    results = @index.search(nil)
    assert_equal @assets.size, results.size
  end

  def test_search_whitespace_only_returns_all
    results = @index.search('   ')
    assert_equal @assets.size, results.size
  end

  # --- filter_by_directory ---

  def test_filter_by_directory
    results = @index.filter_by_directory('Furniture/Tables')
    assert_equal 3, results.size
  end

  def test_filter_by_directory_no_match
    results = @index.filter_by_directory('Nonexistent')
    assert_equal [], results
  end

  def test_filter_by_directory_not_recursive
    results = @index.filter_by_directory('Furniture')
    assert_equal [], results # only Furniture/Tables and Furniture/Chairs exist
  end

  # --- search_in_directory ---

  def test_search_in_directory
    results = @index.search_in_directory('walnut', 'Furniture/Tables')
    assert_equal 2, results.size
  end

  def test_search_in_directory_empty_query
    results = @index.search_in_directory('', 'Furniture/Tables')
    assert_equal 3, results.size
  end

  # --- filter_by_subtree ---

  def test_filter_by_subtree_includes_exact_and_children
    results = @index.filter_by_subtree('Furniture')
    assert_equal 4, results.size # Tables (3) + Chairs (1)
  end

  def test_filter_by_subtree_leaf_directory
    results = @index.filter_by_subtree('Furniture/Chairs')
    assert_equal 1, results.size
  end

  def test_filter_by_subtree_no_match
    results = @index.filter_by_subtree('Nonexistent')
    assert_equal [], results
  end

  def test_filter_by_subtree_does_not_match_partial_names
    # "Furniture" should not match a hypothetical "Furniture2" directory
    asset = build_asset('Shelf_A_1x1.png', directory: 'Furniture2/Shelves')
    index = AssetManager::Index.new(@assets + [asset])
    results = index.filter_by_subtree('Furniture')
    assert_equal 4, results.size # only original Furniture assets
  end

  # --- search_in_subtree ---

  def test_search_in_subtree
    results = @index.search_in_subtree('wood', 'Furniture')
    assert_equal 4, results.size # 3 tables + 1 chair, all have "wood" tag
  end

  def test_search_in_subtree_empty_query
    results = @index.search_in_subtree('', 'Furniture')
    assert_equal 4, results.size
  end

  # --- all_directories ---

  def test_all_directories
    dirs = @index.all_directories
    assert_equal 4, dirs.size
    assert_includes dirs, 'Furniture/Tables'
    assert_includes dirs, 'Furniture/Chairs'
    assert_includes dirs, 'Lightsources/Braziers'
    assert_includes dirs, 'Textures/Grass'
  end

  def test_all_directories_sorted
    dirs = @index.all_directories
    assert_equal dirs.sort, dirs
  end

  # --- child_categories ---

  def test_child_categories_returns_immediate_children
    cats = @index.child_categories('Furniture', @assets)
    assert_includes cats, 'Tables'
    assert_includes cats, 'Chairs'
    assert_equal 2, cats.size
  end

  def test_child_categories_ordered_by_count
    cats = @index.child_categories('Furniture', @assets)
    # Tables has 3 assets, Chairs has 1
    assert_equal 'Tables', cats.first
  end

  # --- filter_by_categories ---

  def test_filter_by_categories
    all = @index.filter_by_subtree('Furniture')
    filtered = @index.filter_by_categories(all, 'Furniture', ['Chairs'])
    assert_equal 1, filtered.size
    assert_equal 'Furniture/Chairs', filtered.first.directory
  end

  def test_filter_by_categories_multiple_or
    all = @index.filter_by_subtree('Furniture')
    filtered = @index.filter_by_categories(all, 'Furniture', %w[Tables Chairs])
    assert_equal 4, filtered.size
  end

  def test_filter_by_categories_empty_returns_all
    all = @index.filter_by_subtree('Furniture')
    filtered = @index.filter_by_categories(all, 'Furniture', [])
    assert_equal all.size, filtered.size
  end

  # --- filter_by_tags ---

  def test_filter_by_tags_single
    filtered = @index.filter_by_tags(@assets, ['walnut'])
    assert_equal 2, filtered.size
    filtered.each { |a| assert_includes a.tags, 'walnut' }
  end

  def test_filter_by_tags_multiple_and
    filtered = @index.filter_by_tags(@assets, %w[table dark])
    assert_equal 1, filtered.size
  end

  def test_filter_by_tags_empty_returns_all
    filtered = @index.filter_by_tags(@assets, [])
    assert_equal @assets.size, filtered.size
  end

  # --- available_tags ---

  def test_available_tags_excludes_variants
    tags = @index.available_tags(@assets)
    refute_includes tags, 'a'
    refute_includes tags, 'b'
    refute_includes tags, 'a1'
  end

  def test_available_tags_includes_real_tags
    tags = @index.available_tags(@assets)
    assert_includes tags, 'wood'
    assert_includes tags, 'table'
  end

  def test_available_tags_respects_limit
    tags = @index.available_tags(@assets, limit: 3)
    assert_equal 3, tags.size
  end

  def test_available_tags_ordered_by_frequency
    tags = @index.available_tags(@assets, limit: 2)
    # "wood" appears in 4 assets (3 tables + 1 chair), "table" in 3
    assert_equal 'wood', tags.first
  end

  # --- in_directory ---

  def test_in_directory_sorted_by_filename
    results = @index.in_directory('Furniture/Tables')
    filenames = results.map(&:filename)
    assert_equal filenames.sort, filenames
  end

  def test_in_directory_empty
    results = @index.in_directory('Nonexistent')
    assert_equal [], results
  end
end
