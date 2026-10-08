# frozen_string_literal: true

module PathMapper
  # What a command says when nobody is looking at a terminal.
  #
  # The desktop entries run with Terminal=false, so everything written to stdout
  # and stderr goes nowhere. That was survivable while the commands were `reset`
  # and `snapshot` - the board shows whether a reset worked, and a snapshot's
  # absence is visible in the directory - and stops being survivable for an
  # upload, which is the step that confirms a map reached the table and has
  # several ways to fail that look identical from a menu item.
  #
  # notify-send comes with libnotify and is on any desktop with a notification
  # daemon. Where it is not, `system` answers nil and the written line is all
  # there is, which is exactly where this started.
  module Notify
    module_function

    def about(summary, body, urgency: 'normal')
      system(
        'notify-send', '--app-name=PathMapper', "--urgency=#{urgency}",
        summary.to_s, body.to_s, out: File::NULL, err: File::NULL
      )
    end
  end

  # One place for the sentence a command ends on, which goes to whoever is
  # watching and, when that is nobody, to the desktop.
  class Report
    def initialize(out, notifying: !out.tty?)
      @out = out
      @notifying = notifying
    end

    def heading(text)
      @out.puts(text)
    end

    def done(text)
      @out.puts(text)
      Notify.about('PathMapper', text) if @notifying
    end

    def failed(text)
      Notify.about('PathMapper', text, urgency: 'critical') if @notifying
      text
    end
  end
end
