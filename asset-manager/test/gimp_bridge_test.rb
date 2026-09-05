# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/asset_manager/gimp_bridge'

class GimpBridgeTest < Minitest::Test
  def setup
    @bridge = AssetManager::MockGimpBridge.new
  end

  def test_load_as_pattern_generates_script
    @bridge.load_as_pattern('/tmp/test.png')
    assert_includes @bridge.last_command, 'file-png-load'
    assert_includes @bridge.last_command, '/tmp/test.png'
    assert_includes @bridge.last_command, 'gimp-context-set-pattern'
    assert_includes @bridge.last_command, 'Clipboard Image'
  end

  def test_load_as_pattern_with_scale
    @bridge.load_as_pattern('/tmp/test.png', scale: 0.5)
    assert_includes @bridge.last_command, '0.5'
  end

  def test_load_as_pattern_default_scale
    @bridge.load_as_pattern('/tmp/test.png')
    assert_includes @bridge.last_command, '1.0'
  end

  def test_load_as_layer_generates_script
    @bridge.load_as_layer('/tmp/test.png', image_id: 1)
    assert_includes @bridge.last_command, 'gimp-file-load-layer'
    assert_includes @bridge.last_command, '/tmp/test.png'
    assert_includes @bridge.last_command, 'gimp-image-insert-layer'
    assert_includes @bridge.last_command, 'gimp-displays-flush'
  end

  def test_layer_template_includes_image_id
    @bridge.load_as_layer('/tmp/test.png', image_id: 42)
    assert_includes @bridge.last_command, '42'
  end

  def test_commands_are_accumulated
    @bridge.load_as_pattern('/tmp/a.png')
    @bridge.load_as_layer('/tmp/b.png', image_id: 1)
    assert_equal 2, @bridge.commands.size
  end

  def test_list_images_returns_mock_data
    assert_equal [[1, '[Untitled]'], [2, 'test-map.xcf']], @bridge.list_images
  end

  def test_escapes_quotes_in_path
    @bridge.load_as_pattern('/tmp/file "with" quotes.png')
    assert_includes @bridge.last_command, 'file \\"with\\" quotes.png'
  end

  def test_escapes_backslashes_in_path
    @bridge.load_as_pattern('/tmp/path\\with\\backslash.png')
    assert_includes @bridge.last_command, 'path\\\\with\\\\backslash.png'
  end
end
