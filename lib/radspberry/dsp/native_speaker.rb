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
    FADE_TIME = 0.02  # 20ms

    @synth = nil
    @gain = 1.0
    @muted = false
    @running = false
    @thread = nil

    def new(synth, opts = {})
      new_synth = synth.is_a?(Class) ? synth.new : synth
      raise ArgumentError, "#{new_synth.class} doesn't respond to ticks!" unless new_synth.respond_to?(:ticks)

      # If already running, just swap the synth (no pop!)
      if @running && NativeAudio.active?
        @synth = new_synth
        @gain = opts.fetch(:volume, 1.0)
        @muted = false
        NativeAudio.unmute if defined?(NativeAudio)
        return self
      end

      # First time: start everything
      @synth = new_synth
      @gain = opts.fetch(:volume, 1.0)
      @muted = false

      NativeAudio.start(@synth.srate.to_i)
      prefill

      @running = true
      @thread = Thread.new { producer_loop }

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
      # Don't actually stop the stream - just let it run silently
      # This prevents pops between play/stop/play cycles
    end

    def shutdown!
      # Actually stop everything (call this on exit)
      return unless @running

      @running = false
      @thread&.join(0.5)
      @thread = nil

      if defined?(NativeAudio) && NativeAudio.active?
        NativeAudio.fade_out
        sleep 0.05
        NativeAudio.stop
      end
    end

    def shutdown
      # Actually stop PortAudio (for cleanup)
      NativeAudio.stop if defined?(NativeAudio) && NativeAudio.active?
    end

    def buffer_level
      return 0.0 unless defined?(NativeAudio) && NativeAudio.active?
      NativeAudio.buffered / 32768.0
    end

    private

    def prefill
      fade_in_samples  # First chunk fades in
      3.times { push_chunk }
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

    def fade_in_samples
      fade_samples = (FADE_TIME * @synth.srate).to_i
      out = @synth.ticks(fade_samples)
      out = out * @gain unless @gain == 1.0
      out = out.respond_to?(:to_a) ? out.to_a : out

      # Simple linear ramp 0→1
      faded = out.each_with_index.map { |s, i| s * (i.to_f / fade_samples) }

      # Unmute and push the fade-in samples
      NativeAudio.unmute
      NativeAudio.push(faded)
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
