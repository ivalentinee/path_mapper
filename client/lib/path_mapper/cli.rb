# frozen_string_literal: true

module PathMapper
  # Arguments in, exit status out.
  #
  # Every failure leaves on stderr with a non-zero status, because the caller is a
  # file manager or a menu entry and neither has a console.
  class CLI
    LOAD_EXTENSION = '.pmload'

    USAGE = <<~TEXT
      Usage:
        path-mapper <file>...       upload each file; what it is comes from its extension
                                    a .xcf map is converted with GIMP on the way
                                    a .pmcharacter is read as org, TOML or JSON
        path-mapper map new [name]  copy the template into the library and open GIMP
        path-mapper map upload      upload the map `map new` last made
        path-mapper save <file>     write a load list: the session, by reference
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
      @report = Report.new(out)
    end

    def run(argv)
      return usage if argv.empty?

      dispatch(argv)
    rescue Config::Missing, Server::Failed, Blob::Invalid, Kind::Unknown, Kind::Mismatch,
           Xcf::Error, Org::Unavailable, Character::Invalid, LoadList::Invalid,
           Library::NoTemplate => e
      @err.puts(e.message)
      @report.failed(e.message)
      1
    end

    private

    def dispatch(argv)
      case argv
      in ['map', *rest] then map(rest)
      in ['save', String => name] then with_server { |server, config| saved(server, config, name) }
      in ['snapshot'] then with_server { |server, config| fetched(server, config) }
      in ['reset'] then with_server { |server, _config| reset(server) }
      else with_server { |server, config| uploading(server, config).upload_all(argv) }
      end
    end

    def map(argv)
      case argv
      in ['new'] then made(nil)
      in ['new', String => name] then made(name)
      in ['upload'] then with_server { |server, config| uploading(server, config).upload_all([last_map]) }
      else usage
      end
    end

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

      retired(config)
      0
    end

    # After the work, not before it: a note about a setting is the least
    # important thing on the screen and must not be the first.
    def retired(config)
      notice = config.retired_notice

      @err.puts(notice) if notice
    end

    # A load list is composed by playing with a session and then writing it
    # down. The name is the game master's and so is the directory: a path typed
    # on the command line is a file handed over directly, which is the one
    # thing the library rule excepts. An existing one is overwritten, because
    # re-saving a session the game master is still arranging would otherwise
    # mean deleting the last attempt first.
    def saved(server, _config, name)
      path = name.end_with?(LOAD_EXTENSION) ? name : name + LOAD_EXTENSION
      File.write(path, LoadList.render(by_kind(server), server.state))

      @report.done("Load list written: #{path}")
    end

    # A token some character names is left out: the .pmcharacter brings it, and
    # naming it here would be the copy that drifts.
    def by_kind(server)
      entities = server.entities.fetch('entities')
      carried = entities.flat_map { |e| [e['token_id'], *e['extra_token_ids']] }.compact

      entities
        .reject { |e| e['kind'] == 'token' && carried.include?(e['id']) }
        .group_by { |e| e['kind'] }
    end

    # A snapshot is the client's idea, not the server's: it is the entities, the
    # state, and the assets those name, put in one file.
    def fetched(server, config)
      @report.done("Snapshot created: #{Snapshot.write(server, config.library.snapshots!, @progress)}")
    end

    def uploading(server, config = nil)
      Upload.new(server, @report, @progress, config&.library)
    end

    # A map to draw on, and GIMP open on it. The launch is deliberately not part
    # of the outcome: the file was made either way, and "made it, could not open
    # it" is a different sentence from "could not make it".
    def made(name)
      config = Config.load
      path = Maps.create(config.library, State.load, name)

      @report.done("Map made: #{path}#{' (GIMP did not open)' unless opened(path)}")
      retired(config)
      0
    end

    def opened(path)
      system('gimp', path, out: File::NULL, err: File::NULL, pgroup: true)
    end

    # The whole point of taking no argument: a map drawn during play goes to the
    # table without anyone learning where it lives. A pointer that no longer
    # resolves is said so and not repaired - no hunting the directory for the
    # highest number, because the wrong map uploaded silently is worse than a
    # refusal.
    def last_map
      remembered = State.load.last_map

      raise Kind::Unknown, 'No map has been made yet. Try: path-mapper map new' if remembered.nil?
      raise Kind::Unknown, "The last map made is gone: #{remembered}" unless File.file?(remembered)

      remembered
    end

    def reset(server)
      server.reset
      @out.puts('Server reset: it now holds nothing')
    end
  end
end
