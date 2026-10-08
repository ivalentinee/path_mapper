# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module PathMapper
  # A map file on its way to the server: an OpenRaster passes through, and a GIMP
  # working file is converted into one first.
  #
  # The conversion runs another program, which nothing else in the client does.
  # It is GIMP's own, driven headless, so a file nobody opened converts exactly as
  # one sitting in front of the author does - which is what makes a map uploadable
  # without a window.
  module Xcf
    # The first nine bytes of every XCF, whatever version follows them.
    SIGNATURE = 'gimp xcf '

    # An OpenRaster is a zip, so this is the first thing a converted file must be.
    ARCHIVE_SIGNATURE = "PK\x03\x04".b

    # gimp-console first, because plain `gimp` cannot do this without a display.
    # GIMP 3.0.4 with -i still initialises GTK, warns "cannot open display",
    # writes nothing and exits 0 - verified on a machine with no X. The console
    # binary ships with GIMP and is built for exactly this; `gimp` stays as the
    # fallback for an installation that somehow lacks it.
    BINARIES = %w[gimp-console gimp].freeze

    ARGUMENTS = %w[--no-data --no-fonts -i --quit --batch-interpreter python-fu-eval -b].freeze

    # What the retired GIMP plug-in allowed, and the reason to keep a bound at
    # all: with none, a GIMP that never exits is a client that never returns, and
    # Open3 waits for the child even after the game master presses Ctrl-C.
    TIMEOUT_SECONDS = 120

    # Gimp.file_load and Gimp.file_save both pick their format from the path, so
    # the ORA exporter is reached by naming the output .ora and nothing else.
    SCRIPT = <<~PYTHON
      image = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.file_new_for_path(%<input>s))
      Gimp.file_save(Gimp.RunMode.NONINTERACTIVE, image, Gio.file_new_for_path(%<output>s))
      image.delete()
    PYTHON

    # Paths are handed to GIMP as Python source, so they are escaped the way
    # Python escapes them. Without this a map called "bob's tavern" ends the
    # literal and fails to convert, and a deliberately named one ends the
    # statement and runs whatever follows.
    PYTHON_ESCAPES = { '\\' => '\\\\', "'" => "\\'", "\n" => '\\n', "\r" => '\\r' }.freeze

    # Anything that stopped a working file from becoming a map. One parent,
    # because a caller that only has to report the failure should not have to
    # know which it was.
    class Error < StandardError
    end

    # GIMP is not installed, and this is the one path that wants it.
    class Unavailable < Error
    end

    # GIMP ran and produced nothing, or produced something that is not a map.
    class Failed < Error
    end

    # GIMP is still going, long past when it should have finished.
    class TimedOut < Error
    end

    module_function

    def xcf?(path)
      File.binread(path, SIGNATURE.bytesize) == SIGNATURE
    rescue SystemCallError
      false
    end

    # What the server should receive for this map, whichever spelling it arrived
    # in. The caller has already read the id off the filename, so a misnamed file
    # costs no conversion - and the step is announced, because a cold GIMP takes
    # seconds and a silent client taking seconds looks like one that has hung.
    def map_bytes(path, progress = Silence.new)
      return File.binread(path) unless xcf?(path)

      progress.step("converting #{File.basename(path)}") { convert(path) }
    end

    def convert(path)
      Dir.mktmpdir('pathmapper-xcf') do |directory|
        output = File.join(directory, 'converted.ora')
        # absolute_path rather than expand_path: a file literally named "~x.xcf"
        # is a path, not a home directory, and expand_path raises on it.
        log = gimp(File.absolute_path(path), output)

        verify!(path, output, log)
        File.binread(output)
      end
    end

    # The exit status is not the verdict. GIMP returns non-zero for things that
    # converted perfectly well and zero for things that did not convert at all,
    # so what was asked for has to be looked at instead. The output is kept only
    # to explain a failure, because it is the only thing that can.
    def gimp(input, output)
      Open3.popen2e(binary, *ARGUMENTS, script(input, output)) do |stdin, merged, running|
        stdin.close
        reader = Thread.new { merged.read }
        # Killing GIMP closes the pipe under this thread, and its complaint
        # about that would be printed over the message explaining the timeout.
        reader.report_on_exception = false

        next give_up(running, reader, input) if running.join(TIMEOUT_SECONDS).nil?

        # scrub: GIMP speaks the machine's locale and can answer in bytes that
        # are not UTF-8, and a message that raises while being built is worse
        # than the failure it was describing.
        reader.value.to_s.scrub
      end
    rescue Errno::ENOENT
      raise Unavailable, unavailable_message
    end

    def give_up(running, reader, input)
      Process.kill('KILL', running.pid)
      reader.kill
      raise TimedOut, timed_out_message(input)
    end

    # Chosen before the run rather than discovered by failing one, because there
    # are two candidates and the first is the one that works headless.
    def binary
      found = BINARIES.find do |candidate|
        ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? do |directory|
          File.executable?(File.join(directory, candidate))
        end
      end

      found || raise(Unavailable, unavailable_message)
    end

    def script(input, output)
      format(SCRIPT, input: python_string(input), output: python_string(output))
    end

    def python_string(value)
      "'#{value.gsub(/[\\'\n\r]/) { |character| PYTHON_ESCAPES[character] }}'"
    end

    # A conversion that half-happened looks like one that happened: GIMP can
    # create the file and then die before writing it, or write part of it. Either
    # would be uploaded as a map and drawn as nothing.
    def verify!(path, output, log)
      raise Failed, failed_message(path, log) unless File.exist?(output) && File.size(output).positive?

      return if File.binread(output, ARCHIVE_SIGNATURE.bytesize) == ARCHIVE_SIGNATURE

      raise Failed, truncated_message(path)
    end

    def failed_message(path, log)
      detail = log.to_s.strip
      message = "GIMP could not convert #{File.basename(path)}"

      detail.empty? ? "#{message}. #{escape_hatch}" : "#{message}:\n#{detail}\n\n#{escape_hatch}"
    end

    def truncated_message(path)
      "GIMP converted #{File.basename(path)} into something that is not a map - " \
        "it stopped partway. #{escape_hatch}"
    end

    def timed_out_message(path)
      "GIMP did not finish converting #{File.basename(path)} within " \
        "#{TIMEOUT_SECONDS} seconds and was stopped. #{escape_hatch}"
    end

    def unavailable_message
      'GIMP is not installed, and converting a .xcf map needs it. ' \
        "Install GIMP, or #{escape_hatch_tail}"
    end

    def escape_hatch
      "Failing that, #{escape_hatch_tail}"
    end

    def escape_hatch_tail
      'export the map from GIMP as OpenRaster and rename it .pmmap, which needs no GIMP here.'
    end
  end
end
