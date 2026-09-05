# frozen_string_literal: true

module AssetManager
  module DirectoryTreeBuilder
    def self.populate(tree_store, directories)
      nodes = {}
      directories.each do |dir_path|
        parts = dir_path.split('/')
        parent_iter = nil
        parts.each_with_index do |part, i|
          key = parts[0..i].join('/')
          unless nodes[key]
            iter = tree_store.append(parent_iter)
            iter[0] = part
            iter[1] = key
            nodes[key] = iter
          end
          parent_iter = nodes[key]
        end
      end
    end
  end
end
