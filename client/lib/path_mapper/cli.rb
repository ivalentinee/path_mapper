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
        path-mapper <file>...   upload each file; what it is comes from its extension
        path-mapper snapshot    fetch a snapshot into the configured directory
        path-mapper reset       unload everything the server holds
    TEXT

    def self.run(argv, out: $stdout, err: $stderr)
      new(out, err).run(argv)
    end

    def initialize(out, err)
      @out = out
      @err = err
    end

    def run(argv)
      return usage if argv.empty?

      case argv
      in ['snapshot'] then with_server { |server, config| fetched(server, config) }
      in ['reset'] then with_server { |server, _config| reset(server) }
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
      yield(Server.new(config), config)
      0
    end

    # A snapshot is the client's idea, not the server's: it is the entities, the
    # state, and the assets those name, put in one file.
    def fetched(server, config)
      @out.puts(Snapshot.write(server, config.snapshots))
    end

    def reset(server)
      server.reset
      @out.puts('Server reset')
    end

    def upload_all(paths, server)
      missing = paths.reject { |path| File.file?(path) }
      raise Kind::Unknown, "No such file: #{missing.join(', ')}" unless missing.empty?

      paths.each { |path| upload(path, server) }
    end

    def upload(path, server)
      kind = Kind.validate!(path, Kind.of(path))

      case kind
      when :adventure then server.declare_all(Commands.new(Blob.open(path), server).adventure)
      when :group then server.declare_all(Commands.new(Blob.open(path), server).group)
      when :map then upload_map(path, server)
      when :token then api_token(path, server)
      when :snapshot then restore(path, server)
      end

      @out.puts("#{File.basename(path)}: #{kind}")
    end

    def upload_map(path, server)
      server.set_scene_map(File.basename(path), File.binread(path))
    end

    def api_token(path, server)
      bytes = File.binread(path)
      image = server.store_asset(Commands.content_name(bytes, 'png'), bytes)
      id = Id.of(path) or raise Kind::Mismatch, "#{File.basename(path)} carries no id in its name"

      server.declare(
        Token.describe(path, bytes).merge('kind' => 'token', 'id' => id, 'image' => image)
      )
    end

    # A snapshot carries everything, so restoring it is hydration: the assets, then
    # the entities that name them, then the state. The server never learns that any
    # of this was a snapshot.
    def restore(path, server)
      snapshot = Snapshot.read(path)
      snapshot.assets.each { |name, bytes| server.store_asset(name, bytes) }
      server.declare_all(snapshot.entities)
      server.apply_state(snapshot.state)
    end
  end
end
