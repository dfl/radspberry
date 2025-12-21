require 'ffi-portaudio'

# these are equivalent:
#  Speaker[ SuperSaw.new ]
#  Speaker.new( SuperSaw )
# example use:
#   Speaker.new( SuperSaw, :frameSize => 2**12)[ :volume => 0.5, :synth => {:spread => 0.9, :freq => 200 }]
#   Speaker[:volume => 0.5, :synth => {:spread => 0.9, :freq => 200 }]

module DSP

  # Initialize sample rate from audio device - call this before creating DSP objects
  def self.init_sample_rate_from_device!
    FFI::PortAudio::API.Pa_Initialize
    device = FFI::PortAudio::API.Pa_GetDefaultOutputDevice
    if device >= 0
      device_info = FFI::PortAudio::API.Pa_GetDeviceInfo(device)
      device_srate = device_info[:defaultSampleRate].to_i
      if device_srate > 0 && device_srate != Base.srate.to_i
        Base.sample_rate = device_srate
      end
    end
    FFI::PortAudio::API.Pa_Terminate
  end

  module Speaker
    extend self

    @@stream = nil

    param_accessor :volume, :delegate => "@@stream.gain", :default => 1.0
    param_accessor :synth,  :delegate => "@@stream"

    # Primary API: Speaker.play(synth) / Speaker.stop
    def play(synth, volume: 1.0, dc_block: false, frame_size: 2**12)
      stop if @@stream
      synth = synth.new if synth.is_a?(Class)
      @@stream = AudioStream.new(synth, frame_size, volume, dc_block: dc_block)
      self
    end

    def stop
      return unless @@stream
      @@stream.stop rescue nil
      @@stream.close rescue nil
      @@stream = nil
    end

    # Legacy API (still works)
    def new(_synth, opts = {})
      play(_synth,
        volume: opts.fetch(:volume, 1.0),
        dc_block: opts.fetch(:dc_block, false),
        frame_size: opts[:frameSize] || 2**12
      )
    end

    def [](opts = {})
      return play(opts) if opts.is_a?(Class) || opts.is_a?(DSP::Base)
      raise ArgumentError, "no stream initialized yet!" unless @@stream
      synth[opts.delete(:synth) || {}]
      opts.each_pair { |k, v| send "#{k}=", v }
      self
    end

    def dc_block=(val)
      @@stream.dc_block = val if @@stream
    end

    def dc_block
      @@stream&.dc_block
    end

    def mute
      @@stream.muted = true if @@stream
    end

    def unmute
      @@stream.muted = false if @@stream
    end

    def muted?
      @@stream&.muted
    end

    def toggle
      @@stream.muted = !@@stream.muted if @@stream
    end

    def playing?
      !!@@stream
    end
  end

  class AudioStream < FFI::PortAudio::Stream
    include FFI::PortAudio
    attr_accessor :gain, :synth, :clip_warning
    attr_reader :muted, :dc_block

    # Fade time in seconds
    FADE_TIME = 0.02  # 20ms

    # Maximum absolute sample value before clipping
    MAX_SAMPLE = 1.0

    def initialize gen, frameSize=2**12, gain=1.0, dc_block: false
      @synth = gen
      @gain  = gain
      @muted = false
      @fade_gain = 1.0
      @fading_out = false
      @fading_in = false
      @clip_warning = true  # Warn on clipping
      @clipped = false

      # Optional DC blocking filter (gentle, ~3.5Hz cutoff)
      @dc_block = dc_block
      @dc_blocker = DCBlocker.new(r: 0.9995) if dc_block

      raise ArgumentError, "#{synth.class} doesn't respond to ticks!" unless @synth.respond_to?(:ticks)
      init!( frameSize )

      # Recalculate fade samples after sample rate is set
      @fade_samples = (FADE_TIME * @synth.srate).to_i
      start
    end

    def dc_block=(val)
      @dc_block = val
      @dc_blocker = val ? DCBlocker.new(r: 0.9995) : nil
    end

    def muted=(val)
      if val && !@muted
        @fading_out = true
        @fading_in = false
      elsif !val && @muted
        @fading_in = true
        @fading_out = false
      end
      @muted = val
    end

    def process input, output, framesPerBuffer, timeInfo, statusFlags, userData
      # Generate samples - always work with plain Arrays for PortAudio
      if @muted && @fade_gain <= 0.0 && !@fading_in
        out = Array.new(framesPerBuffer, 0.0)
      else
        # Get samples and convert to Array immediately
        raw = @synth.ticks(framesPerBuffer)
        out = raw.respond_to?(:to_a) ? raw.to_a : Array(raw)

        # Apply gain
        out.map! { |s| s * @gain } unless @gain == 1.0

        # Apply optional DC blocking
        if @dc_blocker
          out.map! { |s| @dc_blocker.tick(s) }
        end

        # Apply fade-out/fade-in
        if @fading_out || @fading_in || @fade_gain < 1.0
          fade_delta = 1.0 / @fade_samples
          out.map! do |sample|
            if @fading_out && @fade_gain > 0.0
              @fade_gain -= fade_delta
              @fade_gain = 0.0 if @fade_gain < 0.0
              @fading_out = false if @fade_gain <= 0.0
            elsif @fading_in && @fade_gain < 1.0
              @fade_gain += fade_delta
              @fade_gain = 1.0 if @fade_gain > 1.0
              @fading_in = false if @fade_gain >= 1.0
            end
            sample * @fade_gain
          end
        end
      end

      # Hard clip and sanitize - protect against NaN/Infinity
      out.map! do |s|
        s = 0.0 if s.nan? || s.infinite?
        s.clamp(-MAX_SAMPLE, MAX_SAMPLE)
      end

      output.write_array_of_float out
      :paContinue
    end

    def init! frameSize=nil
      API.Pa_Initialize

      input = nil

      output = API::PaStreamParameters.new
      output[:device]                    = API.Pa_GetDefaultOutputDevice
      output[:suggestedLatency]          = API.Pa_GetDeviceInfo(output[:device])[:defaultHighOutputLatency]
      output[:hostApiSpecificStreamInfo] = nil
      output[:channelCount]              = 1
      output[:sampleFormat]              = API::Float32

      # Use the globally configured sample rate (set at module load time)
      open( input, output, @synth.srate.to_i, frameSize )

      # Register cleanup only once
      unless @@exit_handler_registered
        @@exit_handler_registered = true
        at_exit do
          API.Pa_Terminate rescue nil
        end
      end
    end

    @@exit_handler_registered = false

  end
end
