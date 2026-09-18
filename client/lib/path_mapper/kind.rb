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
  module Kind
    class Unknown < StandardError
    end

    class Mismatch < StandardError
    end

    BY_EXTENSION = {
      '.pmadventure' => :adventure,
      '.pmgroup' => :group,
      '.pmtoken' => :token,
      '.pmmap' => :map,
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
      when :adventure, :group then require_archive_entry!(path, Blob::MANIFEST, kind)
      when :map then require_archive_entry!(path, 'mimetype', kind)
      when :token then require_png!(path)
      when :snapshot then require_archive!(path, kind)
      end
      kind
    end

    def shown(extension)
      extension.empty? ? 'a name with no extension' : extension
    end

    def require_png!(path)
      signature = File.binread(path, 8)
      return if signature == "\x89PNG\r\n\x1A\n".b

      raise Mismatch, "#{File.basename(path)} is named .pmtoken but is not a PNG"
    end

    def require_archive!(path, kind)
      Zip::File.open(path, &:size)
    rescue Zip::Error
      raise Mismatch, "#{File.basename(path)} is named .pm#{kind} but is not an archive"
    end

    def require_archive_entry!(path, entry, kind)
      require_archive!(path, kind)
      return if Zip::File.open(path) { |zip| zip.find_entry(entry) }

      raise Mismatch, "#{File.basename(path)} is named .pm#{kind} but has no #{entry}"
    end
  end
end
