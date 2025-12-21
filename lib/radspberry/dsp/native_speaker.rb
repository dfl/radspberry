# Native audio speaker - uses C extension for glitch-free audio
#
# The C callback runs without the GVL, so Ruby work doesn't affect audio.

begin
  require_relative '../../radspberry_audio/radspberry_audio'
rescue LoadError => e
  # Extension not compiled yet
  warn "NativeAudio extension not loaded: #{e.message}"
  warn "Run: cd ext/radspberry_audio && ruby extconf.rb && make"
end

module DSP
  module NativeSpeaker
    extend self

    CHUNK_SIZE = 1024

    @synth = nil
    @gain = 1.0
    @muted = false
    @running = false
    @thread = nil

    def new(synth, opts = {})
      stop if @running

      @synth = synth.is_a?(Class) ? synth.new : synth
      @gain = opts.fetch(:volume, 1.0)
      @muted = false

      raise ArgumentError, "#{@synth.class} doesn't respond to ticks!" unless @synth.respond_to?(:ticks)

      # Start native audio
      $stderr.puts "DEBUG: Starting NativeAudio..." if $DEBUG
      NativeAudio.start(@synth.srate.to_i)
      $stderr.puts "DEBUG: NativeAudio started" if $DEBUG

      # Pre-fill buffer
      $stderr.puts "DEBUG: Prefilling..." if $DEBUG
      prefill
      $stderr.puts "DEBUG: Prefilled" if $DEBUG

      # Start producer thread
      @running = true
      @thread = Thread.new { producer_loop }
      $stderr.puts "DEBUG: Producer thread started" if $DEBUG

      self
    end

    def [](opts = {})
      return new(opts) if opts.is_a?(Class) || opts.is_a?(DSP::Base)
      opts.each_pair { |k, v| send("#{k}=", v) }
      self
    end

    def synth
      @synth
    end

    def synth=(val)
      @synth = val
    end

    def volume
      @gain
    end

    def volume=(val)
      @gain = val
    end

    def mute
      @muted = true
    end

    def unmute
      @muted = false
    end

    def muted?
      @muted
    end

    def stop
      @running = false
      @thread&.join(1.0)
      @thread = nil
      NativeAudio.stop if defined?(NativeAudio) && NativeAudio.active?
    end

    def buffer_level
      return 0.0 unless defined?(NativeAudio) && NativeAudio.active?
      NativeAudio.buffered / 32768.0
    end

    private

    def prefill
      4.times { push_chunk }
    end

    def push_chunk
      samples = if @muted
        Array.new(CHUNK_SIZE, 0.0)
      else
        out = @synth.ticks(CHUNK_SIZE)
        out = out * @gain unless @gain == 1.0
        out.respond_to?(:to_a) ? out.to_a : out
      end
      NativeAudio.push(samples)
    end

    def producer_loop
      while @running
        if NativeAudio.available > CHUNK_SIZE
          push_chunk
        else
          sleep 0.001  # Buffer full, wait a bit
        end
      end
    end
  end
end
