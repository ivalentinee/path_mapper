# frozen_string_literal: true

require 'test_helper'
require 'stringio'

class ProgressTest < Minitest::Test
  def setup
    @out = StringIO.new
    @progress = PathMapper::Progress.new(@out)
  end

  def test_formats_bytes_in_the_largest_unit_that_fits
    assert_equal '512 B', PathMapper::Progress.size(512)
    assert_equal '1.0 KB', PathMapper::Progress.size(1024)
    assert_equal '1.1 MB', PathMapper::Progress.size(1_200_000)
  end

  def test_returns_what_the_block_returned
    assert_equal :done, @progress.step('a thing') { :done }
  end

  def test_names_the_step_before_running_it
    seen = nil
    @progress.step('uploading cave.ora') { seen = @out.string }

    assert_includes seen, 'uploading cave.ora'
  end

  def test_closes_the_line_when_the_step_succeeds
    @progress.step('a thing') { :ok }

    assert_equal "  [1] a thing ... ok\n", @out.string
  end

  def test_numbers_each_step
    3.times { |n| @progress.step("step #{n}") { nil } }

    assert_equal %w[1 2 3], @out.string.scan(/\[(\d)\]/).flatten
  end

  # The whole reason the label is printed first: a run that dies mid-asset has
  # already said which asset, and says so again on the way out.
  def test_marks_the_line_failed_and_reraises
    error = assert_raises(RuntimeError) do
      @progress.step('uploading cave.ora') { raise 'connection reset' }
    end

    assert_equal 'connection reset', error.message
    assert_includes @out.string, 'uploading cave.ora'
    assert_includes @out.string, 'FAILED'
  end

  def test_silence_runs_the_block_and_prints_nothing
    out = StringIO.new
    $stdout = out
    begin
      assert_equal :done, PathMapper::Silence.new.step('a thing') { :done }
    ensure
      $stdout = STDOUT
    end

    assert_empty out.string
  end
end
