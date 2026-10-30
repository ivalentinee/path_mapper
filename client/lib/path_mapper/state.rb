# frozen_string_literal: true

require 'toml-rb'
require 'fileutils'

module PathMapper
  # What the program remembers between runs, which is not what the game master
  # configured.
  #
  # Two facts, and they are kept separate on purpose. The counter is derivable
  # from the last path - the id is in the name - but then a map deleted or moved
  # after a session restarts the numbering, and the next one reissues an id the
  # server has already seen. The counter only ever rises; the path is a
  # convenience that may go stale.
  #
  # It lives under XDG_STATE_HOME rather than beside the configuration, which is
  # what that directory is for: remembered between restarts, not important
  # enough to back up, and never hand-edited. Writing into config.toml would
  # mean a program rewriting a file a person owns, losing their comments.
  class State
    def self.path
      base = ENV.fetch('XDG_STATE_HOME', nil)
      base = File.join(Dir.home, '.local', 'state') if base.nil? || base.empty?
      File.join(base, 'path-mapper', 'state.toml')
    end

    def self.load(path = self.path)
      values = File.exist?(path) ? TomlRB.load_file(path) : {}
      new(values, path)
    end

    attr_reader :counter, :last_map

    def initialize(values, path = self.class.path)
      @path = path
      @counter = values['counter'].is_a?(Integer) ? values['counter'] : 0
      @last_map = values['last_map']
    end

    # The id is claimed before the file it names is made. A copy that fails
    # afterwards burns an id, which costs nothing - ids are free and these maps
    # are disposable - where reissuing one would put two maps on the same
    # surface.
    def claim_id
      @counter += 1
      write
      @counter
    end

    def remember(map_path)
      @last_map = map_path
      write
      map_path
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, TomlRB.dump(to_h))
    end

    def to_h
      { 'counter' => @counter }.tap { |values| values['last_map'] = @last_map if @last_map }
    end
  end
end
