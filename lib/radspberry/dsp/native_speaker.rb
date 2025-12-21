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

      new_gain = opts.fetch(:volume, 1.0)

      # If stream is already running, just swap the synth (no click!)
      if @running && defined?(NativeAudio) && NativeAudio.active?
        # Fade out current sound
        NativeAudio.fade_out
        timeout = Time.now + 0.1
        until NativeAudio.muted? || Time.now > timeout
          sleep 0.002
        end

        # Swap synth and gain
        @synth = new_synth
        @gain = new_gain

        # Clear buffer and fade back in
        NativeAudio.clear
        fade_in_samples

        return self
      end

      # Fresh start - no stream running yet
      stop if @running

      @synth = new_synth
      @gain = new_gain
      @muted = false

      # Start native audio
      NativeAudio.start(@synth.srate.to_i)

      # Pre-fill buffer
      prefill

      # Start producer thread
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
      return unless @running

      # Stop the producer thread first
      @running = false
      @thread&.join(0.5)
      @thread = nil

      # Fade out then stop the stream
      if defined?(NativeAudio) && NativeAudio.active?
        NativeAudio.fade_out

        # Wait for fade to complete
        timeout = Time.now + 0.1
        until NativeAudio.muted? || Time.now > timeout
          sleep 0.002
        end

        # Actually stop the stream so we can start a new one
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
