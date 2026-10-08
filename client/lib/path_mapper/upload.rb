# frozen_string_literal: true

require 'json'

module PathMapper
  # One piece of a session, on its way to the server.
  #
  # Split out of CLI, which is argv in and an exit status out. This is the arm per
  # kind of file and the phrasing that says what each one did - two tiers that grew
  # inside a class whose own description is neither of them.
  class Upload
    attr_reader :library, :report, :progress

    def initialize(server, report, progress, library = nil)
      @server = server
      @report = report
      @progress = progress
      @library = library
    end

    def upload_all(paths)
      missing = paths.reject { |path| File.file?(path) }
      raise Kind::Unknown, "No such file: #{missing.join(', ')}" unless missing.empty?

      paths.each { |path| upload(path) }
    end

    # Every branch reports what happened rather than what the file was. A client
    # invoked from a menu entry gets one chance to say whether it did
    # anything, and "adventure" is not an answer to that.
    def upload(path)
      kind = Kind.validate!(path, Kind.of(path))

      @report.heading("#{File.basename(path)} -> #{kind}")

      @report.done(
        case kind
        when :character then upload_characters(path)
        when :load then load_list(path)
        when :map then upload_map(path)
        when :wallpaper then upload_wallpaper(path)
        when :token then upload_token(path)
        when :snapshot then restore(path)
        end
      )
    end

    # A map arrives the way every piece does: its bytes as an asset, then an
    # entity naming them. There is no route that puts a map onto whatever the
    # table happens to be looking at, and the game master switches to it
    # themselves.
    # A character and the tokens it points at. The character goes after its own
    # references resolve and not before, so a file whose third character is
    # broken sends the first two and names the third - a character is the unit
    # a game master thinks in.
    def upload_characters(path)
      declared = Character.read(path)
      sent = declared.map { |character| upload_character(character, path) }

      "#{sent.length} #{plural(sent.length, 'character')} loaded: #{sent.join(', ')}"
    end

    def upload_character(character, path)
      main = token_for(character, character.token, path) || refuse(character)
      extras = character.extras.filter_map { |extra| token_for(character, extra, path) }

      @server.declare(character.fields.merge(
        'kind' => 'character', 'token_id' => main, 'extra_token_ids' => extras
      ).compact)

      named(character)
    end

    # A character that cannot be put on a board is not one, so nothing of it is
    # sent. An extra that is not there is a gap and the character still goes.
    def refuse(character)
      raise Character::Invalid,
            "#{named(character)} wants a token that is not there: #{character.token.target}"
    end

    def named(character)
      character.fields['character_name'] || character.id
    end

    # The character names and owns what it points at, whatever the token's own
    # bytes say: the bytes cannot know which character uses them.
    def token_for(character, reference, path)
      file = resolve(reference, path) or return missing(reference)
      bytes = File.binread(file)
      id = Id.of(file)

      image = sending(file, bytes) { @server.store_asset(Asset.name(bytes, 'png'), bytes) }
      described = Token.describe(file, bytes)
      @server.declare(described.merge(
        'kind' => 'token', 'id' => id, 'image' => image,
        'owner' => character.id, 'name' => reference.name || described['name']
      ).compact)

      id
    end

    def resolve(reference, path)
      return @library&.find(reference.target, :token) unless reference.path?

      candidate = File.expand_path(reference.target, File.dirname(path))

      File.file?(candidate) ? candidate : nil
    end

    # An extra that is not there is a gap, not a broken character.
    def missing(reference)
      @report.heading("  no token for #{reference.target}")
      nil
    end

    # A load list is read, not uploaded. Loading says what that means.
    def load_list(path)
      Loading.new(self).read(path)
    end

    def apply_state(state)
      @server.apply_state(state)
    end

    def upload_map(path)
      id = Id.of(path) or raise Kind::Mismatch, "#{File.basename(path)} carries no id in its name"
      bytes = Xcf.map_bytes(path, @progress)

      file = sending(path, bytes) { @server.store_asset(Asset.name(bytes, 'ora'), bytes) }
      name = Id.name_of(path)
      # compact, because a map nobody named has no name rather than a null one,
      # and the contract refuses a null. Reachable since the client started
      # issuing ids of its own: pm0001-0000000001.xcf has no descriptive half.
      @server.declare({ 'kind' => 'map', 'id' => id, 'file' => file, 'name' => name }.compact)

      "Map loaded: #{name || id}"
    end

    # A wallpaper is a container holding one image, named for the id it carries.
    # Unpacking it here rather than sending the archive keeps the server's side
    # of this identical to every other piece: bytes, then an entity naming them.
    def upload_wallpaper(path)
      id = Id.of(path) or raise Kind::Mismatch, "#{File.basename(path)} carries no id in its name"
      name, bytes = Blob.single_image(path)

      extension = File.extname(name).delete_prefix('.')
      file = sending(path, bytes) { @server.store_asset(Asset.name(bytes, extension), bytes) }
      @server.declare({ 'kind' => 'wallpaper', 'id' => id, 'file' => file })

      "Wallpaper loaded: #{Id.name_of(path) || id}"
    end

    def upload_token(path)
      bytes = File.binread(path)
      id = Id.of(path) or raise Kind::Mismatch, "#{File.basename(path)} carries no id in its name"

      image = sending(path, bytes) { @server.store_asset(Asset.name(bytes, 'png'), bytes) }
      described = Token.describe(path, bytes)
      @server.declare(described.merge('kind' => 'token', 'id' => id, 'image' => image))

      "Token loaded: #{described['name']} (#{described['size']} #{plural(described['size'], 'cell')})"
    end

    # One phrasing for "this file, this many bytes, on its way", wherever it is a
    # file on disk rather than an entry inside a blob.
    def plural(count, word)
      count == 1 ? word : "#{word}s"
    end

    def sending(path, bytes, &)
      @progress.step("#{File.basename(path)} (#{Progress.size(bytes.bytesize)})", &)
    end

    # A snapshot carries everything, so restoring it is hydration: the assets, then
    # the entities that name them, then the state. The server never learns that any
    # of this was a snapshot.
    def restore(path)
      snapshot = Snapshot.read(path)
      replay(snapshot)

      "Snapshot restored: #{entities(snapshot.entities.size)}, " \
        "#{snapshot.assets.size} #{plural(snapshot.assets.size, 'asset')}"
    end

    def replay(snapshot)
      snapshot.assets.each do |name, bytes|
        @progress.step("#{name} (#{Progress.size(bytes.bytesize)})") { @server.store_asset(name, bytes) }
      end

      @progress.step("declaring #{entities(snapshot.entities.size)}") do
        @server.declare_all(snapshot.entities)
      end

      @progress.step('applying game state') { @server.apply_state(snapshot.state) }
    end
  end
end
