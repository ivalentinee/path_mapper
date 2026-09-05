# frozen_string_literal: true

module AssetManager
  Asset = Struct.new(
    :path,
    :filename,
    :directory,
    :tags,
    :grid_size,
    :extension,
    keyword_init: true
  )

  module Scanner
    GRID_SIZE_PATTERN = /\A(\d+)x(\d+)\z/
    EXTENSIONS = '*.{png,jpg,PNG,JPG}'

    def self.scan(root_path)
      root = File.expand_path(root_path)
      pattern = File.join(root, '**', EXTENSIONS)

      Dir.glob(pattern).map { |path| parse_asset(path, root) }
    end

    def self.parse_asset(path, root)
      extname = File.extname(path)
      filename = File.basename(path, extname)
      directory = relative_directory(path, root)
      extension = extname.delete_prefix('.').downcase
      tokens = filename.split('_')
      grid_size = extract_grid_size(tokens)

      Asset.new(
        path: path,
        filename: filename,
        directory: directory,
        tags: tokens.map(&:downcase),
        grid_size: grid_size,
        extension: extension
      )
    end

    def self.relative_directory(path, root)
      dir = File.dirname(path)
      dir == root ? '.' : dir.delete_prefix("#{root}/")
    end

    def self.extract_grid_size(tokens)
      return nil if tokens.empty?

      last = tokens.last
      match = last.match(GRID_SIZE_PATTERN)
      return unless match

      tokens.pop
      [match[1].to_i, match[2].to_i]
    end

    private_class_method :parse_asset, :relative_directory, :extract_grid_size
  end
end
