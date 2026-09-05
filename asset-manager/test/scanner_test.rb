# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'fileutils'

class ScannerTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('asset-test')
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def create_file(*parts)
    path = File.join(@tmpdir, *parts)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path)
    path
  end

  def test_finds_png_files
    create_file('Table_A_1x1.png')
    create_file('Chair_B_2x2.png')
    assets = AssetManager::Scanner.scan(@tmpdir)
    assert_equal 2, assets.size
  end

  def test_finds_jpg_files
    create_file('Texture_A.jpg')
    assets = AssetManager::Scanner.scan(@tmpdir)
    assert_equal 1, assets.size
    assert_equal 'jpg', assets.first.extension
  end

  def test_finds_nested_files
    create_file('Furniture', 'Tables', 'Table_A_1x1.png')
    create_file('Furniture', 'Chairs', 'Chair_B_2x2.png')
    assets = AssetManager::Scanner.scan(@tmpdir)
    assert_equal 2, assets.size
  end

  def test_ignores_non_image_files
    create_file('readme.txt')
    create_file('Table_A_1x1.png')
    assets = AssetManager::Scanner.scan(@tmpdir)
    assert_equal 1, assets.size
  end

  def test_parses_filename_without_extension
    create_file('Table_Round_Wood_A_1x1.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_equal 'Table_Round_Wood_A_1x1', asset.filename
  end

  def test_extracts_tags_from_filename
    create_file('Table_Round_Wood_Walnut_F_1x1.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_equal %w[table round wood walnut f], asset.tags
  end

  def test_extracts_grid_size
    create_file('Table_A_2x3.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_equal [2, 3], asset.grid_size
  end

  def test_grid_size_nil_when_absent
    create_file('Cliff_Path_A2.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_nil asset.grid_size
    assert_equal %w[cliff path a2], asset.tags
  end

  def test_relative_directory
    create_file('Furniture', 'Tables', 'Table_A_1x1.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_equal 'Furniture/Tables', asset.directory
  end

  def test_root_directory_is_dot
    create_file('Table_A_1x1.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_equal '.', asset.directory
  end

  def test_extension_is_downcased
    create_file('Table_A_1x1.PNG')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_equal 'png', asset.extension
  end

  def test_tags_are_downcased
    create_file('Table_Round_WOOD_A_1x1.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_includes asset.tags, 'wood'
    refute_includes asset.tags, 'WOOD'
  end

  def test_grid_size_removed_from_tags
    create_file('Table_A_1x1.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    refute_includes asset.tags, '1x1'
  end

  def test_empty_directory
    assets = AssetManager::Scanner.scan(@tmpdir)
    assert_equal [], assets
  end

  def test_real_fa_filename_pattern
    create_file('Altar_Stone_Earthy_F_Runner_Black_A_2x1.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_equal %w[altar stone earthy f runner black a], asset.tags
    assert_equal [2, 1], asset.grid_size
  end

  def test_real_fa_filename_no_grid
    create_file('Cliff_Stone_Volcanic_A3_Path_A2.png')
    asset = AssetManager::Scanner.scan(@tmpdir).first
    assert_nil asset.grid_size
    assert_equal %w[cliff stone volcanic a3 path a2], asset.tags
  end
end
