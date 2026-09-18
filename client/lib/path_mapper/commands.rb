# frozen_string_literal: true

require 'digest'

module PathMapper
  # Turns a blob into the sequence of commands the server takes.
  #
  # There is no description any more. An adventure is a declaration of the
  # adventure, one of each scene, and one of every map and token those scenes name
  # - and a group, and a snapshot, are sequences of the same kind. The server has
  # one way in, so this has one thing to produce.
  #
  # The ids matter. Every one used to be read off a filename, and content
  # addressing destroys filenames, so they are read here while the original names
  # still exist and sent alongside.
  class Commands
    def self.content_name(bytes, extension)
      "#{Digest::SHA256.digest(bytes)[0, 8].unpack1('H*')}.#{extension}"
    end

    def initialize(blob, server, progress = Silence.new)
      @blob = blob
      @server = server
      @progress = progress
    end

    # How many assets actually travelled. Uploading is lazy, so this is only
    # meaningful once a sequence has been built - which is when it gets reported.
    def uploaded
      @uploader ? @uploader.size : 0
    end

    def adventure
      stored = uploader
      manifest = @blob.manifest

      once(
        [adventure_command(manifest)] +
          (manifest['scenes'] || []).each_with_index.flat_map do |scene, order|
            scene_commands(scene, order, stored)
          end
      )
    end

    def group
      stored = uploader
      manifest = @blob.manifest
      players = manifest['players'] || []

      once(
        players.flat_map { |player| player_tokens(player, stored) } +
          [{
            'kind' => 'group',
            'id' => @blob.id,
            'title' => manifest['title'],
            'file' => @blob.filename,
            'players' => players.map { |player| player_entry(player, stored) }
          }]
      )
    end

    private

    # Two scenes sharing a map declare it twice. Replacing an entity with itself is
    # harmless, but sending it twice is work nobody asked for - and it makes any
    # count of what was sent a lie. Keeping the first occurrence preserves the
    # ordering that puts a thing before whatever names it.
    def once(commands)
      commands.uniq { |command| command['id'] }
    end

    def adventure_command(manifest)
      {
        'kind' => 'adventure',
        'id' => @blob.id,
        'title' => manifest['title'],
        'file' => @blob.filename,
        'wallpaper' => manifest['wallpaper'] && uploader[manifest['wallpaper']],
        'urls' => manifest['urls'] || []
      }
    end

    # A map and every token a scene names are entities in their own right, declared
    # before the scene that refers to them.
    def scene_commands(scene, order, stored)
      map_name = scene['map'] && scene['map']['file']
      map_id = map_name && Id.of(map_name)
      tokens = scene['tokens'] || []

      map_commands(map_id, map_name, stored) +
        tokens.map { |token| token_command(token, stored) } +
        [scene_command(scene, order, map_id, tokens)]
    end

    def scene_command(scene, order, map_id, tokens)
      {
        'kind' => 'scene',
        'id' => scene['id'],
        'ref' => scene['ref'],
        'name' => scene['name'],
        'type' => scene['type'],
        'order' => order,
        'map_id' => map_id,
        'tokens' => tokens.map { |token| { 'id' => Id.of(token['image']) } },
        'place_tokens' => scene['place_tokens'] || []
      }
    end

    def map_commands(id, name, stored)
      return [] unless id

      [{ 'kind' => 'map', 'id' => id, 'file' => stored[name] }]
    end

    def token_command(token, stored)
      {
        'kind' => 'token',
        'id' => Id.of(token['image']),
        'name' => token['name'],
        'owner' => token['owner'] || 'npc',
        'size' => token['size'],
        'image' => stored[token['image']]
      }
    end

    def player_tokens(player, stored)
      extras = player['extra_tokens'] || []

      [player_token(player['token'], player['character_name'], stored)] +
        extras.map { |extra| player_token(extra['image'], extra['name'], stored) }
    end

    # A player's own token and the extras they carry differ only in where the name
    # is read from. Both are one-cell tokens owned by nobody until a scene says
    # otherwise, which is what a group is allowed to know.
    def player_token(image, name, stored)
      {
        'kind' => 'token',
        'id' => Id.of(image),
        'name' => name,
        'owner' => 'npc',
        'size' => 1,
        'image' => stored[image]
      }
    end

    def player_entry(player, stored)
      player
        .merge('token_id' => Id.of(player['token']), 'token' => stored[player['token']])
        .merge('extra_tokens' => (player['extra_tokens'] || []).map do |extra|
          extra.merge('id' => Id.of(extra['image']), 'image' => stored[extra['image']])
        end)
    end

    # Uploads on first reference, so an entry nothing names never travels. Blobs
    # carry source files - an .xcf beside the .ora it was exported from - and
    # sending those would waste exactly what this design exists to save.
    def uploader
      @uploader ||= begin
        assets = @blob.assets

        Hash.new do |stored, name|
          bytes = assets.fetch(name) { raise Blob::Invalid, "#{@blob.filename} has no #{name}" }
          stored[name] = upload(name, bytes)
        end
      end
    end

    # Names the asset on the way out as well as on the progress line, because the
    # two are read by different things: the line by whoever is watching, the
    # message by a plug-in dialog that shows an exception and nothing else.
    def upload(name, bytes)
      @progress.step("#{name} (#{Progress.size(bytes.bytesize)})") do
        @server.store_asset(Commands.content_name(bytes, extension(name)), bytes)
      end
    rescue Server::Failed => e
      raise Server::Failed, "Uploading #{name}: #{e.message}"
    end

    def extension(name)
      File.extname(name).delete_prefix('.')
    end
  end
end
