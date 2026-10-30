# frozen_string_literal: true

require 'json'

module PathMapper
  # A load list, walked.
  #
  # Not an upload, which is why it is not in Upload: nothing here is a file the
  # game master handed over. The list names pieces they already have, and each
  # name becomes the upload they would have asked for by naming the file
  # themselves.
  #
  # Nested lists first, then pieces, then state - state last because it places
  # pieces, and the outermost list's state last of all, so the file that was
  # named wins where more than one carries one.
  #
  # The recursion counts rather than phrases. One sentence is composed at the
  # top however deep the lists go, and a list nested three down does not get to
  # announce itself.
  class Loading
    def initialize(upload)
      @upload = upload
    end

    def read(path)
      count = pieces_of(path)

      "Loaded: #{count} #{@upload.plural(count, 'piece')}"
    end

    def pieces_of(path)
      list = LoadList.read(path)
      nested = list['load'].sum { |reference| nested_list(reference, path) }
      here = list['pieces'].count { |reference| loaded?(reference, path) }

      apply(list['game_state']) if list['game_state']

      nested + here
    end

    def nested_list(reference, from)
      file = resolve(reference, from)
      return pieces_of(file) if file

      report_missing(reference)
      0
    end

    def loaded?(reference, from)
      file = resolve(reference, from)
      if file.nil?
        report_missing(reference)
        return false
      end

      @upload.upload(file)
      true
    end

    def resolve(reference, from)
      LoadList.resolve(reference, from, @upload.library)
    end

    # A name nothing answers to is reported and passed over. A list is a long
    # enough thing that stopping at the first gap would mean learning about
    # them one game night at a time.
    def report_missing(reference)
      @upload.report.heading("  nothing named #{reference}")
    end

    def apply(state)
      @upload.progress.step('applying game state') { @upload.apply_state(JSON.parse(state)) }
    end
  end
end
