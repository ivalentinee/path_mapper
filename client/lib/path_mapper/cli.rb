# frozen_string_literal: true

module PathMapper
  # Arguments in, exit status out.
  #
  # Every failure leaves on stderr with a non-zero status, because the callers are
  # a file manager and a GIMP plug-in: neither has a console, and the plug-in shows
  # whatever comes back here.
  class CLI
    USAGE = <<~TEXT
      Usage:
        path-mapper <file>...       upload each file; what it is comes from its extension
        path-mapper start <id>      begin an empty game under that adventure id
        path-mapper snapshot        fetch a snapshot into the configured directory
        path-mapper reset           unload everything the server holds
    TEXT

    def self.run(argv, out: $stdout, err: $stderr)
      new(out, err).run(argv)
    end

    def initialize(out, err)
      @out = out
      @err = err
      @progress = Progress.new(out)
    end

    def run(argv)
      return usage if argv.empty?

      case argv
      in ['snapshot'] then with_server { |server, config| fetched(server, config) }
      in ['reset'] then with_server { |server, _config| reset(server) }
      in ['start', String => id] then with_server { |server, _config| start(server, id) }
      in ['start', *] then usage
      else with_server { |server, _config| upload_all(argv, server) }
      end
    rescue Config::Missing, Server::Failed, Blob::Invalid, Kind::Unknown, Kind::Mismatch => e
      @err.puts(e.message)
      1
    end

    private

    def usage
      @err.puts(USAGE)
      2
    end

    def with_server
      config = Config.load
      server = Server.new(config)

      begin
        yield(server, config)
      ensure
        server.close
      end

      0
    end

    # A snapshot is the client's idea, not the server's: it is the entities, the
    # state, and the assets those name, put in one file.
    def fetched(server, config)
      @out.puts("Snapshot created: #{Snapshot.write(server, config.snapshots, @progress)}")
    end

    def reset(server)
      server.reset
      @out.puts('Server reset: it now holds nothing')
    end

    # An empty game is an adventure and no scenes. There is no special path for it
    # on the server, and no reason there should be: it is hydration that stops after
    # the first command.
    def start(server, id)
      raise Kind::Mismatch, "#{id} is not an id" unless Id.of("#{id}-x")

      server.declare('kind' => 'adventure', 'id' => id, 'title' => 'Empty game')
      @out.puts("Empty game started: #{id}")
    end

    def upload_all(paths, server)
      missing = paths.reject { |path| File.file?(path) }
      raise Kind::Unknown, "No such file: #{missing.join(', ')}" unless missing.empty?

      paths.each { |path| upload(path, server) }
    end

    # Every branch reports what happened rather than what the file was. A client
    # invoked from a menu entry or a plug-in gets one chance to say whether it did
    # anything, and "adventure" is not an answer to that.
    def upload(path, server)
      kind = Kind.validate!(path, Kind.of(path))

      @out.puts("#{File.basename(path)} -> #{kind}")

      @out.puts(
        case kind
        when :adventure then load_blob(path, server, :adventure)
        when :group then load_blob(path, server, :group)
        when :map then upload_map(path, server)
        when :token then upload_token(path, server)
        when :snapshot then restore(path, server)
        end
      )
    end

    def load_blob(path, server, kind)
      commands = Commands.new(Blob.open(path), server, @progress)
      sequence = commands.public_send(kind)

      @progress.step("declaring #{entities(sequence.size)}") do
        server.declare_all(sequence)
      end

      named = sequence.find { |command| command['kind'] == kind.to_s }
      "#{kind.capitalize} loaded: #{named['title']} (#{tally(sequence, commands)})"
    end

    def tally(sequence, commands)
      counts = sequence.group_by { |command| command['kind'] }.transform_values(&:size)
      parts = %w[scene token map].filter_map do |kind|
        "#{counts[kind]} #{kind}#{'s' if counts[kind] > 1}" if counts[kind]
      end

      (parts + ["#{commands.uploaded} #{plural(commands.uploaded, 'asset')} uploaded"]).join(', ')
    end

    def plural(count, word)
      count == 1 ? word : "#{word}s"
    end

    def entities(count)
      count == 1 ? '1 entity' : "#{count} entities"
    end

    def upload_map(path, server)
      bytes = File.binread(path)
      sending(path, bytes) { server.set_scene_map(File.basename(path), bytes) }

      'Map loaded onto the active scene'
    end

    def upload_token(path, server)
      bytes = File.binread(path)
      id = Id.of(path) or raise Kind::Mismatch, "#{File.basename(path)} carries no id in its name"

      image = sending(path, bytes) { server.store_asset(Commands.content_name(bytes, 'png'), bytes) }
      described = Token.describe(path, bytes)
      server.declare(described.merge('kind' => 'token', 'id' => id, 'image' => image))

      "Token loaded: #{described['name']} (#{described['size']} #{plural(described['size'], 'cell')})"
    end

    # One phrasing for "this file, this many bytes, on its way", wherever it is a
    # file on disk rather than an entry inside a blob.
    def sending(path, bytes, &)
      @progress.step("#{File.basename(path)} (#{Progress.size(bytes.bytesize)})", &)
    end

    # A snapshot carries everything, so restoring it is hydration: the assets, then
    # the entities that name them, then the state. The server never learns that any
    # of this was a snapshot.
    def restore(path, server)
      snapshot = Snapshot.read(path)
      replay(snapshot, server)

      "Snapshot restored: #{entities(snapshot.entities.size)}, " \
        "#{snapshot.assets.size} #{plural(snapshot.assets.size, 'asset')}"
    end

    def replay(snapshot, server)
      snapshot.assets.each do |name, bytes|
        @progress.step("#{name} (#{Progress.size(bytes.bytesize)})") { server.store_asset(name, bytes) }
      end

      @progress.step("declaring #{entities(snapshot.entities.size)}") do
        server.declare_all(snapshot.entities)
      end

      @progress.step('applying game state') { server.apply_state(snapshot.state) }
    end
  end
end
