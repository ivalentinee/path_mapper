# frozen_string_literal: true

module PathMapper
  # What the client is doing, while it is still doing it.
  #
  # An upload is mostly waiting on one asset after another, and the callers - a
  # file manager entry, a GIMP plug-in - offer no spinner and no console. Without a
  # line per asset there is nothing between "started" and "finished" but silence,
  # and silence is indistinguishable from a hang.
  #
  # Each line is written before the work it names, so an upload that dies mid-asset
  # has already said which one. That is the whole point: a timeout is only
  # actionable if you know what it timed out on.
  class Progress
    UNITS = %w[B KB MB GB].freeze

    def self.size(bytes)
      value = bytes.to_f
      unit = UNITS.first

      UNITS.drop(1).each do |larger|
        break if value < 1024

        value /= 1024
        unit = larger
      end

      format(unit == UNITS.first ? '%d %s' : '%.1f %s', value, unit)
    end

    def initialize(out)
      @out = out
      @count = 0
    end

    # Prints the label, runs the block, then closes the line with its verdict.
    def step(label)
      @count += 1
      @out.print("  [#{@count}] #{label} ... ")
      flush

      result = yield
      finish('ok')
      result
    rescue StandardError
      finish('FAILED')
      raise
    end

    # Flushed as it is written, not merely at exit. Failures are reported on stderr,
    # which is unbuffered, so a stdout left sitting in a buffer would print the
    # reason for a failure above the line saying which step failed.
    def finish(verdict)
      @out.puts(verdict)
      flush
    end

    # A file manager reads this as a stream and a plug-in reads it after the fact.
    # Neither sees a half-written line, so every line is pushed as it is made.
    def flush
      @out.flush
    rescue IOError, NoMethodError
      nil
    end
  end

  # Stands in where no reporting is wanted, so callers never test for nil.
  class Silence
    def step(_label)
      yield
    end

    def flush; end
  end
end
