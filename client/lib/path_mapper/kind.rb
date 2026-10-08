# frozen_string_literal: true

require 'zip'

module PathMapper
  # What a file is, decided by its extension and nothing else.
  #
  # The file manager has only the extension to go on, so the extensions exist
  # regardless; having the client read the same key means the two cannot drift
  # apart. The cost is that a renamed file lies, and the answer to that is to
  # validate after dispatching rather than to sniff content instead - sniffing
  # would reintroduce the second dispatch mechanism this avoids.
  #
  # One kind has two content formats: a map is an OpenRaster or the GIMP working
  # file it was drawn in. The bytes are read to tell those apart, which is not a
  # second dispatch - the extension has already said "map", and all that is left
  # is which reader to use.
  module Kind
    class Unknown < StandardError
    end

    class Mismatch < StandardError
    end

    BY_EXTENSION = {
      '.pmtoken' => :token,
      '.pmcharacter' => :character,
      '.pmload' => :load,
      '.pmmap' => :map,
      '.xcf' => :map,
      '.pmwallpaper' => :wallpaper,
      '.pmsnapshot' => :snapshot
    }.freeze

    module_function

    def of(path)
      extension = File.extname(path).downcase
      BY_EXTENSION.fetch(extension) do
        raise Unknown, "#{File.basename(path)}: #{shown(extension)} is not a PathMapper file " \
                       "(expected one of #{BY_EXTENSION.keys.join(', ')})"
      end
    end

    def validate!(path, kind)
      case kind
      when :map then require_map!(path)
      when :character, :load then nil
      when :token then require_png!(path)
      when :wallpaper, :snapshot then require_archive!(path, kind)
      end
      kind
    end

    def shown(extension)
      extension.empty? ? 'a name with no extension' : extension
    end

    # Either spelling of a map: the OpenRaster the server reads, or the GIMP
    # working file the client converts into one. The extension still decides
    # that this is a map - the bytes only say which of the two it is.
    def require_map!(path)
      return if Xcf.xcf?(path)

      require_archive_entry!(path, 'mimetype', :map)
    end

    # What the file calls itself, for a message about the file. Saying ".pmmap"
    # to someone holding a .xcf asserts something false about the name they can
    # see, which is the one thing an error must not do.
    def named(path)
      extension = File.extname(path)

      extension.empty? ? 'a PathMapper file' : extension
    end

    def require_png!(path)
      signature = File.binread(path, 8)
      return if signature == "\x89PNG\r\n\x1A\n".b

      raise Mismatch, "#{File.basename(path)} is named .pmtoken but is not a PNG"
    end

    def require_archive!(path, _kind)
      Zip::File.open(path, &:size)
    rescue Zip::Error
      raise Mismatch, "#{File.basename(path)} is named #{named(path)} but is not an archive"
    end

    def require_archive_entry!(path, entry, kind)
      require_archive!(path, kind)
      return if Zip::File.open(path) { |zip| zip.find_entry(entry) }

      raise Mismatch, "#{File.basename(path)} is named #{named(path)} but has no #{entry}"
    end
  end
end
