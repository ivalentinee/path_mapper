# frozen_string_literal: true

require 'digest'
require 'fileutils'

module AssetManager
  class ThumbnailCache
    THUMB_SIZE = 64

    def initialize(asset_root)
      @cache_dir = File.join(asset_root, '.thumbnails')
      FileUtils.mkdir_p(@cache_dir)
    end

    def get(asset)
      cache_path = cache_path_for(asset)

      if File.exist?(cache_path) && File.mtime(cache_path) >= File.mtime(asset.path)
        cache_path
      else
        generate(asset, cache_path)
      end
    end

    def get_pixbuf(asset)
      path = get(asset)
      GdkPixbuf::Pixbuf.new(file: path)
    rescue StandardError => e
      warn "Failed to load thumbnail for #{asset.path}: #{e.message}"
      nil
    end

    def get_preview(asset, size: 256)
      pixbuf = GdkPixbuf::Pixbuf.new(file: asset.path)
      scale_to_fit(pixbuf, size)
    rescue StandardError => e
      warn "Failed to load preview for #{asset.path}: #{e.message}"
      nil
    end

    private

    def cache_path_for(asset)
      hash = Digest::MD5.hexdigest(asset.path)
      File.join(@cache_dir, "#{hash}.png")
    end

    def generate(asset, cache_path)
      pixbuf = GdkPixbuf::Pixbuf.new(file: asset.path)
      thumb = scale_to_fit(pixbuf, THUMB_SIZE)
      thumb.save(cache_path, 'png')
      cache_path
    rescue StandardError => e
      warn "Failed to generate thumbnail for #{asset.path}: #{e.message}"
      nil
    end

    def scale_to_fit(pixbuf, max_size)
      w = pixbuf.width
      h = pixbuf.height
      return pixbuf if w <= max_size && h <= max_size

      if w > h
        new_w = max_size
        new_h = (h * max_size.to_f / w).to_i
      else
        new_h = max_size
        new_w = (w * max_size.to_f / h).to_i
      end

      new_w = [new_w, 1].max
      new_h = [new_h, 1].max
      pixbuf.scale_simple(new_w, new_h, GdkPixbuf::InterpType::BILINEAR)
    end
  end
end
