# frozen_string_literal: true

require 'test_helper'
require 'fileutils'

# GIMP is not installed in the development container, and mocking the call would
# test the mock. A stub named `gimp`, first on PATH, exercises the real argument
# list, the real Open3 call and the real output-file verdict - only the pixels
# are fictional.
class XcfTest < Minitest::Test
  # A real header: the nine-byte signature plus the version the shipped template
  # carries. Xcf::SIGNATURE is the prefix; this is a whole file's beginning.
  HEADER = "#{PathMapper::Xcf::SIGNATURE}v011\0".freeze

  # The stub has to write where the real GIMP was told to, and the only place
  # that path exists is inside the Python it was handed. This lifts it back out.
  OUTPUT_PATH_FROM_ARGV = %(printf '%s' "$@" | sed -n "s/.*file_new_for_path('\\([^']*\\.ora\\)').*/\\1/p")

  ORA = "PK\x03\x04and the rest of a zip"

  def setup
    @directory = Dir.mktmpdir('xcf-test')
    @bin = File.join(@directory, 'bin')
    Dir.mkdir(@bin)
    @path = File.join(@directory, 'pm0001-0000000001-keep.xcf')
    File.binwrite(@path, "#{HEADER}rest of the file")
    @original_path = ENV.fetch('PATH', '')
  end

  def teardown
    ENV['PATH'] = @original_path
    FileUtils.remove_entry(@directory)
  end

  def test_recognises_an_xcf_by_its_first_nine_bytes
    assert PathMapper::Xcf.xcf?(@path)
  end

  # Without this the signature could be shortened to "gimp" and nothing would
  # notice; GIMP's own console output starts that way.
  def test_a_near_miss_is_not_an_xcf
    near = File.join(@directory, 'pm0001-0000000002-near.xcf')
    File.binwrite(near, 'gimp 2.10 is not a file format')

    refute PathMapper::Xcf.xcf?(near)
  end

  def test_does_not_mistake_an_openraster_for_one
    ora = File.join(@directory, 'pm0001-0000000003-ora.pmmap')
    File.binwrite(ora, ORA)

    refute PathMapper::Xcf.xcf?(ora)
  end

  def test_a_missing_file_is_not_an_xcf_and_does_not_raise
    refute PathMapper::Xcf.xcf?(File.join(@directory, 'nothing-here.xcf'))
  end

  # The "and for nothing else" half of "GIMP is required for .xcf and for
  # nothing else": an OpenRaster is handed over untouched, with no GIMP on PATH
  # at all to make sure none is wanted.
  def test_an_openraster_is_passed_through_without_gimp
    ora = File.join(@directory, 'pm0001-0000000003-ora.pmmap')
    File.binwrite(ora, ORA)
    ENV['PATH'] = @bin

    assert_equal ORA, PathMapper::Xcf.map_bytes(ora)
  end

  def test_a_working_file_is_converted_and_the_step_announced
    stub_gimp_writing(ORA)
    reported = []
    progress = Object.new
    progress.define_singleton_method(:step) do |label, &block|
      reported << label
      block.call
    end

    assert_equal ORA, PathMapper::Xcf.map_bytes(@path, progress)
    assert_equal ['converting pm0001-0000000001-keep.xcf'], reported
  end

  def test_hands_back_what_gimp_wrote
    stub_gimp_writing(ORA)

    assert_equal ORA, PathMapper::Xcf.convert(@path)
  end

  # Asserting on the script rather than on substrings of the whole argv: with
  # the latter, swapping input for output - telling GIMP to save over the
  # author's working file - still passed.
  def test_tells_gimp_to_load_the_working_file_and_save_an_ora
    script = PathMapper::Xcf.script('/maps/keep.xcf', '/tmp/x/converted.ora')
    load_line, save_line = script.lines

    assert_includes load_line, 'file_load'
    assert_includes load_line, "'/maps/keep.xcf'"
    assert_includes save_line, 'file_save'
    assert_includes save_line, "'/tmp/x/converted.ora'"
  end

  def test_runs_gimp_headless_and_tells_it_to_quit
    assert_includes PathMapper::Xcf::ARGUMENTS, '-i'
    assert_includes PathMapper::Xcf::ARGUMENTS, '--quit'
    assert_includes PathMapper::Xcf::ARGUMENTS, 'python-fu-eval'
  end

  # Plain `gimp` cannot convert without a display: GIMP 3.0.4 with -i warns
  # "cannot open display", writes nothing and exits 0.
  def test_prefers_the_console_binary
    assert_equal 'gimp-console', PathMapper::Xcf::BINARIES.first
  end

  # A map called "bob's tavern" is a legal name, and before the paths were
  # escaped it converted to a Python SyntaxError.
  def test_a_quote_in_the_name_is_escaped_rather_than_ending_the_literal
    script = PathMapper::Xcf.script("/maps/bob's tavern.xcf", '/tmp/x.ora')

    assert_includes script, "'/maps/bob\\'s tavern.xcf'"
  end

  # The same defect's other face: everything after the quote was Python the
  # script would run.
  def test_a_crafted_name_cannot_end_the_statement
    crafted = "/maps/x'));__import__('os').system('touch PWNED');print(('.xcf"
    script = PathMapper::Xcf.script(crafted, '/tmp/x.ora')

    refute_includes script, "__import__('os')"
    assert_includes script, "__import__(\\'os\\')"
  end

  def test_a_backslash_and_a_newline_are_escaped
    script = PathMapper::Xcf.script("/maps/a\\b\nc.xcf", '/tmp/x.ora')

    assert_includes script, '/maps/a\\\\b\\nc.xcf'
    assert_equal 3, script.lines.length
  end

  # The case GIMP actually produces, and the reason the exit status is not the
  # verdict: it says everything went well and there is no file.
  def test_a_zero_exit_with_no_file_is_still_a_failure
    stub_gimp("echo 'all is well'\nexit 0\n")

    error = assert_raises(PathMapper::Xcf::Failed) { PathMapper::Xcf.convert(@path) }

    assert_includes error.message, 'pm0001-0000000001-keep.xcf'
    assert_includes error.message, '.pmmap'
  end

  # Distinguished from the case below: nothing was written, which reads as the
  # conversion not happening, not as it happening badly.
  def test_an_empty_output_file_is_a_failure_rather_than_an_empty_map
    stub_gimp(%(: > "$(#{OUTPUT_PATH_FROM_ARGV})"\n))

    error = assert_raises(PathMapper::Xcf::Failed) { PathMapper::Xcf.convert(@path) }

    assert_includes error.message, 'could not convert'
    refute_includes error.message, 'stopped partway'
  end

  # A GIMP that dies partway leaves a file that exists and is not a map; it
  # would otherwise be uploaded and drawn as nothing.
  def test_an_output_that_is_not_an_archive_is_a_failure
    stub_gimp_writing('truncated, not a zip')

    error = assert_raises(PathMapper::Xcf::Failed) { PathMapper::Xcf.convert(@path) }

    assert_includes error.message, 'stopped partway'
  end

  def test_carries_what_gimp_said_about_the_failure
    stub_gimp("echo 'no such GIR typelib' >&2\nexit 1\n")

    error = assert_raises(PathMapper::Xcf::Failed) { PathMapper::Xcf.convert(@path) }

    assert_includes error.message, 'no such GIR typelib'
  end

  # GIMP speaks the machine's locale, and a message that raises while being
  # built is worse than the failure it was describing.
  def test_output_that_is_not_utf8_does_not_break_the_message
    stub_gimp("printf 'konnte nicht \\377\\376 oeffnen\\n' >&2\nexit 1\n")

    error = assert_raises(PathMapper::Xcf::Failed) { PathMapper::Xcf.convert(@path) }

    assert_includes error.message, 'konnte nicht'
  end

  def test_says_gimp_is_missing_rather_than_failing_obscurely
    ENV['PATH'] = @bin

    error = assert_raises(PathMapper::Xcf::Unavailable) { PathMapper::Xcf.convert(@path) }

    assert_includes error.message, 'GIMP is not installed'
    assert_includes error.message, '.pmmap'
  end

  # Without a bound, a GIMP that never exits is a client that never returns -
  # and Open3 waits for the child even after Ctrl-C.
  def test_a_gimp_that_never_finishes_is_stopped
    stub_gimp("sleep 30\n")
    PathMapper::Xcf.send(:remove_const, :TIMEOUT_SECONDS)
    PathMapper::Xcf.const_set(:TIMEOUT_SECONDS, 1)

    error = assert_raises(PathMapper::Xcf::TimedOut) { PathMapper::Xcf.convert(@path) }

    assert_includes error.message, 'pm0001-0000000001-keep.xcf'
  ensure
    PathMapper::Xcf.send(:remove_const, :TIMEOUT_SECONDS)
    PathMapper::Xcf.const_set(:TIMEOUT_SECONDS, 120)
  end

  # The guarantee, not the implementation: whatever route the bytes take, the
  # converted file does not outlive the call. Dir.mktmpdir's block form gives
  # this today, and a refactor away from it would lose it silently.
  def test_leaves_no_converted_file_behind
    stub_gimp_writing(ORA)
    before = scratch_directories

    PathMapper::Xcf.convert(@path)

    assert_equal before, scratch_directories
  end

  def test_leaves_no_converted_file_behind_when_it_fails
    stub_gimp("exit 1\n")
    before = scratch_directories

    assert_raises(PathMapper::Xcf::Failed) { PathMapper::Xcf.convert(@path) }
    assert_equal before, scratch_directories
  end

  private

  def scratch_directories
    Dir.glob(File.join(Dir.tmpdir, 'pathmapper-xcf*'))
  end

  # Both names, because the client prefers gimp-console and falls back to gimp:
  # a stub for only one would let a real GIMP on this machine answer instead.
  def stub_gimp(body)
    PathMapper::Xcf::BINARIES.each do |name|
      script = File.join(@bin, name)
      File.write(script, "#!/bin/sh\n#{body}")
      File.chmod(0o755, script)
    end
    ENV['PATH'] = "#{@bin}:#{@original_path}"
  end

  def stub_gimp_writing(bytes)
    source = File.join(@directory, 'source.ora')
    File.binwrite(source, bytes)
    stub_gimp(%(cp #{source} "$(#{OUTPUT_PATH_FROM_ARGV})"\n))
  end
end
