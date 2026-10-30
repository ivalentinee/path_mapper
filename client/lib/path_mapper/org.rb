# frozen_string_literal: true

require 'json'
require 'open3'

module PathMapper
  # An org file, read by the thing that owns the format.
  #
  # Emacs is where org came from and where the game master's files are written,
  # so the client runs it rather than approximating it - the same bargain as
  # GIMP and `.xcf`. Nothing of PathMapper's is installed into Emacs: the form
  # below travels as an argument and is gone when the process exits.
  #
  # What comes back is one entry per headline: its depth, its text, and its
  # drawer properties, with every property's org links already separated into
  # type, path and description. Org does that parsing, because org owns the
  # syntax - a path with spaces in it, which a real file has, is exactly what a
  # hand-written reader gets wrong.
  module Org
    # -Q so the author's init is not loaded: their configuration may be slow,
    # may be broken, and is not needed to read a file. enable-local-variables
    # is nil because an org file can carry `eval:` forms. Batch mode declines
    # those on its own, having nobody to ask for confirmation, but a guarantee
    # resting on the variable is better than one resting on that.
    COMMAND = ['emacs', '-Q', '--batch', '--eval', '(setq enable-local-variables nil)'].freeze

    # org-mode is forced: the file is named .pmcharacter, so auto-mode-alist -
    # which knows .org and nothing else - would leave it in fundamental-mode and
    # every org function would find an empty outline.
    # One form, because --eval reads a single s-expression and discards
    # whatever follows it: with two, only the first would run.
    FORM = <<~ELISP.freeze
      (progn
      (org-mode)
      (princ (json-encode (org-map-entries (lambda ()
        (list (cons "level" (org-outline-level))
              (cons "heading" (org-get-heading t t t t))
              (cons "properties"
                (mapcar (lambda (pair)
                  (list (cons "key" (car pair))
                        (cons "value" (cdr pair))
                        (cons "links" (org-element-map
                          (org-element-parse-secondary-string
                            (cdr pair) (org-element-restriction 'paragraph))
                          'link
                          (lambda (l) (list (cons "type" (org-element-property :type l))
                                            (cons "path" (org-element-property :path l))
                                            (cons "text" (substring-no-properties
                                                           (or (car (org-element-contents l)) "")))))))))#{' '}
                  (org-entry-properties nil 'standard)))))))))
    ELISP

    class Unavailable < StandardError
    end

    module_function

    def entries(path)
      JSON.parse(read(path)) || []
    rescue JSON::ParserError
      []
    end

    # The path is an argument, never part of the form. A filename interpolated
    # into code is how `Xcf` once turned a map's name into arbitrary Python.
    def read(path)
      output, = Open3.capture2e(*COMMAND, "--visit=#{File.absolute_path(path)}", '--eval', FORM)
      output.to_s.scrub
    rescue Errno::ENOENT
      raise Unavailable, unavailable_message
    end

    def unavailable_message
      'Emacs is not installed, and reading an .org file needs it. ' \
        'Install Emacs, or write the same thing in TOML or JSON.'
    end
  end
end
