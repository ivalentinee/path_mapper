# frozen_string_literal: true

require 'zip'
require 'toml-rb'

module PathMapper
  # A blob, unpacked in memory.
  #
  # The unpacked form never reaches disk and never outlives the run. The server
  # sees the entries, one at a time; it never sees the archive.
  # An archive holding one image, which is what a wallpaper is.
  #
  # What used to be here as well was the package reader: a manifest naming the
  # pieces inside an .pmadventure or a .pmgroup. Those formats are gone, and the
  # pieces they held upload one at a time.
  class Blob
    class Invalid < StandardError
    end

    IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .webp].freeze

    def self.single_image(path)
      Zip::File.open(path) do |zip|
        entry = zip.find { |e| e.file? && IMAGE_EXTENSIONS.include?(File.extname(e.name).downcase) }
        raise Invalid, "#{File.basename(path)} holds no image" unless entry

        [entry.name, entry.get_input_stream.read]
      end
    end
  end
end
