module DebugExtension
  class Debug
    def initialize(args)
      @args = args
      @active = false
      @debug_logs = []
      @static_debug_logs = {}
      @static_primitives = []
      @last_debug_y = 720
      @reset_handlers = []
    end

    def time_block_last_execute(name)
      start = Time.now.to_f
      yield
      duration_ms = ((Time.now.to_f - start) * 1000).floor
      static_log(:"time_#{name}", "Last execution of #{name}: #{duration_ms}ms")
    end

    def static_primitives
      @static_primitives
    end

    def active?
      @active
    end

    def static_log(name, message)
      @static_debug_logs[name] = message
    end

    def log(message, pos = nil)
      return if $gtk.production

      label_pos = pos || [0, @last_debug_y]
      @last_debug_y -= 20 unless pos
      @debug_logs << [label_pos.x, label_pos.y, message, 255, 255, 255].label
    end

    def tick
      return if $gtk.production

      handle_debug_function

      add_static_logs
      render_debug_logs
      render_debug_primitives
    end

    def on_reset(&block)
      @reset_handlers << block
    end

    private

    DEBUG_FUNCTIONS = {
      f9: :toggle_debug,
      f11: :reset_with_same_seed,
      f12: :reset
    }.freeze

    def handle_debug_function
      pressed_key = DEBUG_FUNCTIONS.keys.find { |key| @args.inputs.keyboard.key_down.send(key) }
      send(DEBUG_FUNCTIONS[pressed_key]) if pressed_key
    end

    def toggle_debug
      @active = !@active
    end

    def reset_with_same_seed
      $gtk.reset
      handle_reset
    end

    def reset
      $gtk.reset seed: (Time.now.to_f * 1000).to_i
      handle_reset
    end

    def handle_reset
      @reset_handlers.each(&:call)
    end

    def add_static_logs
      @static_debug_logs.each_value do |message|
        log(message)
      end
    end

    def render_debug_logs
      log($gtk.current_framerate.to_i.to_s)
      log('DEBUG MODE') if @active

      @args.outputs.debug << @debug_logs
      @debug_logs.clear
      @last_debug_y = 720
    end

    def render_debug_primitives
      @args.outputs.debug << @static_primitives
    end
  end

  # Adds args.debug
  module Args
    def debug
      @debug ||= Debug.new(self)
    end
  end

  # Runs the debug tick
  module Runtime
    def tick_core
      @args.debug.tick
      super
    end
  end
end

GTK::Args.include DebugExtension::Args
GTK::Runtime.prepend DebugExtension::Runtime
