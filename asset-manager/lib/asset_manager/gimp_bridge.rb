# frozen_string_literal: true

require 'socket'

module AssetManager
  class GimpBridge
    PATTERN_TEMPLATE = <<~SCRIPT
      (let* ((img (car (%<loader>s RUN-NONINTERACTIVE "%<path>s" "%<path>s")))
             (w (car (gimp-image-get-width img)))
             (h (car (gimp-image-get-height img))))
        (gimp-image-scale img (round (* w %<scale>s)) (round (* h %<scale>s)))
        (let* ((drawables (car (gimp-image-get-selected-drawables img))))
          (gimp-selection-all img)
          (gimp-edit-copy drawables)
          (gimp-image-delete img)
          (gimp-context-set-pattern (car (gimp-pattern-get-by-name "Clipboard Image")))))
    SCRIPT

    LAYER_TEMPLATE = <<~SCRIPT
      (let* ((layer (car (gimp-file-load-layer RUN-NONINTERACTIVE %<image_id>d "%<path>s"))))
        (gimp-image-insert-layer %<image_id>d layer 0 -1)
        (gimp-displays-flush))
    SCRIPT

    LIST_IMAGES_SCRIPT = <<~SCRIPT
      (let* ((imgs (car (gimp-get-images))) (i 0) (result ""))
        (while (< i (vector-length imgs))
          (set! result (string-append result
            (number->string (vector-ref imgs i)) ":"
            (car (gimp-image-get-name (vector-ref imgs i))) "\\n"))
          (set! i (+ i 1)))
        result)
    SCRIPT

    LOADERS = {
      'png' => 'file-png-load',
      'jpg' => 'file-jpeg-load',
      'jpeg' => 'file-jpeg-load'
    }.freeze

    def load_as_pattern(path, scale: 1.0)
      ext = File.extname(path).delete_prefix('.').downcase
      loader = LOADERS[ext] || 'file-png-load'
      command = format(PATTERN_TEMPLATE, path: escape_path(path), scale: scale, loader: loader)
      send_command(command)
    end

    def load_as_layer(path, image_id:)
      command = format(LAYER_TEMPLATE, path: escape_path(path), image_id: image_id)
      send_command(command)
    end

    def list_images
      # Returns array of [id, name] pairs
      []
    end

    private

    def escape_path(path)
      path.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
    end

    def send_command(command)
      do_send(command)
    end

    def do_send(_command)
      raise NotImplementedError, 'Subclasses must implement do_send'
    end
  end

  class RealGimpBridge < GimpBridge
    HOST = '127.0.0.1'
    PORT = 10_008
    TIMEOUT = 5

    def initialize(on_error: nil)
      super()
      @on_error = on_error
    end

    def list_images
      response = send_to_scriptfu(LIST_IMAGES_SCRIPT.strip)
      parse_image_list(response)
    rescue StandardError => e
      warn "[GIMP Bridge] list_images: #{e.message}"
      []
    end

    private

    def parse_image_list(response)
      return [] unless response && response.bytesize > 4

      # Script-Fu response: 1 byte status + 3 bytes length + response text
      # Response text is a quoted string like "19:19-mehri.xcf\n1:[Untitled]\n"
      text = response[4..].force_encoding('UTF-8')
      text = text.delete_prefix('"').delete_suffix('"')
      text.split('\n').filter_map do |line|
        id_str, name = line.split(':', 2)
        next unless id_str && name

        [id_str.strip.to_i, name.strip]
      end
    end

    def do_send(command)
      response = send_to_scriptfu(command.strip)
      check_response(response)
    rescue Errno::ECONNREFUSED
      handle_error('Cannot connect to GIMP. Start Script-Fu server: Filters → Script-Fu → Start Server')
    rescue StandardError => e
      handle_error(e.message)
    end

    def send_to_scriptfu(payload)
      socket = TCPSocket.new(HOST, PORT)
      socket.write(['G', payload.bytesize].pack('a1n'))
      socket.write(payload)

      response = socket.wait_readable(TIMEOUT) ? socket.read_nonblock(4096) : nil
      socket.close
      response
    rescue IO::WaitReadable
      socket&.close
      nil
    end

    def check_response(response)
      return unless response&.bytesize&.positive?

      # Script-Fu server response: 1 byte status (0=ok, 1=error) + rest
      # In practice, success responses contain "(#t)" or similar
      status_byte = response.getbyte(0)
      return if status_byte.zero?

      # Extract readable text from response
      text = response.gsub(/[^[:print:]\s]/, '').strip
      return if text.empty? || text == '(#t)'

      warn "[GIMP Error] #{text}"
    end

    def handle_error(message)
      warn "[GIMP Bridge] #{message}"
      @on_error&.call(message)
    end
  end

  class MockGimpBridge < GimpBridge
    attr_reader :last_command, :commands

    def initialize
      super
      @commands = []
      @last_command = nil
    end

    def list_images
      [[1, '[Untitled]'], [2, 'test-map.xcf']]
    end

    private

    def do_send(command)
      @last_command = command.strip
      @commands << @last_command
      puts "[MockGimp] #{@last_command[0, 80]}..."
    end
  end
end
