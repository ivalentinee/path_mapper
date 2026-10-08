# frozen_string_literal: true

require 'test_helper'

# The file manager has nothing but the extension to go on, and the client has
# Kind::BY_EXTENSION. The XML says the two cannot drift apart; this is what
# makes that true. They had drifted - .pmadventure and .pmgroup were still
# registered after being removed, and .pmcharacter, .pmload and .pmwallpaper
# were never registered at all, so double-clicking one did nothing.
class DesktopTest < Minitest::Test
  DESKTOP = File.expand_path('../desktop', __dir__)

  def test_every_kind_the_client_reads_is_registered
    assert_equal extensions_the_client_reads, registered_extensions
  end

  # A type the upload entry does not list is registered and unreachable: the
  # file manager knows what the file is and has nothing to open it with.
  def test_the_upload_entry_offers_every_registered_type
    listed = upload_entry_mime_types.reject { |type| type == 'image/x-xcf' }

    assert_equal registered_types.sort, listed.sort
  end

  # .xcf is offered so a map can be handed over without exporting it, but
  # PathMapper must not become its default handler - double-clicking one opens
  # GIMP. install.sh captures and restores the previous default.
  def test_xcf_is_offered_but_never_claimed
    assert_includes upload_entry_mime_types, 'image/x-xcf'
    refute_includes registered_types, 'image/x-xcf'
    assert_includes install_script, 'xdg-mime query default image/x-xcf'
  end

  # install.sh names the types a second time, to make the upload entry their
  # default. A type it misses is registered, offered, and still not what a
  # double-click reaches.
  def test_install_makes_the_upload_entry_the_default_for_each
    named = install_script[/^for type in (.+); do$/, 1].split.sort

    assert_equal registered_types.map { |type| type.delete_prefix(PREFIX) }.sort, named
  end

  # update-mime-database skips a malformed file without saying so, and
  # xdg-mime then reports success having registered nothing. A double dash
  # anywhere in an XML comment is enough to do it, which is a hazard whenever
  # someone writes an em dash as two hyphens in the explanation at the top.
  def test_no_comment_contains_a_double_dash
    offenders = xml.scan(/<!--(.*?)-->/m).flatten.select { |body| body.include?('--') }

    assert_empty offenders, 'a double dash in an XML comment makes update-mime-database skip the file'
  end

  def test_every_registered_type_has_exactly_one_glob
    assert_equal registered_types.length, registered_extensions.length
  end

  PREFIX = 'application/x-pathmapper-'

  private

  def xml
    @xml ||= File.read(File.join(DESKTOP, 'pathmapper-types.xml'))
  end

  def install_script
    @install_script ||= File.read(File.join(DESKTOP, 'install.sh'))
  end

  def extensions_the_client_reads
    PathMapper::Kind::BY_EXTENSION.keys.reject { |extension| extension == '.xcf' }.sort
  end

  def registered_extensions
    xml.scan(%r{<glob pattern="\*(\.[a-z]+)"\s*/>}).flatten.sort
  end

  def registered_types
    xml.scan(/<mime-type type="([^"]+)">/).flatten
  end

  def upload_entry_mime_types
    File.read(File.join(DESKTOP, 'pathmapper-upload.desktop'))[/^MimeType=(.+)$/, 1]
        .split(';').reject(&:empty?)
  end
end
