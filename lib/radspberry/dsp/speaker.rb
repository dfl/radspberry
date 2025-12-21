require 'ffi-portaudio'

# these are equivalent:
#  Speaker[ SuperSaw.new ]
#  Speaker.new( SuperSaw )
# example use:
#   Speaker.new( SuperSaw, :frameSize => 2**12)[ :volume => 0.5, :synth => {:spread => 0.9, :freq => 200 }]
#   Speaker[:volume => 0.5, :synth => {:spread => 0.9, :freq => 200 }]

module DSP

  module Speaker
    extend self

    @@stream = nil

    param_accessor :volume, :delegate => "@@stream.gain", :default => 1.0
    param_accessor :synth,  :delegate => "@@stream"

    def new _synth, opts={}
      @@stream.try(:close)
      _synth = _synth.new if _synth.is_a?(Class) # instantiate
      frame_size = opts[:frameSize] || 2**12
      gain = opts.fetch(:volume, 1.0)
      @@stream = AudioStream.new(_synth, frame_size, gain)
      self
    end

    def [] opts={}
      return new(opts) if opts.is_a?( Class ) || opts.is_a?( DSP::Base )
      raise ArgumentError, "no stream initialized yet!" unless @@stream
      synth[ opts.delete(:synth) || {} ]
      opts.each_pair{ |k,v| send "#{k}=", v }
      self
    end

    def mute
      @@stream.muted = true
    end

    def unmute
      @@stream.muted = false
    end

    def muted?
      @@stream.muted
    end

    def toggle
      @@stream.muted = !@@stream.muted
    end

  end

  class AudioStream < FFI::PortAudio::Stream
    include FFI::PortAudio
    attr_accessor :gain, :synth, :clip_warning
    attr_reader :muted

    # Fade time in seconds
    FADE_TIME = 0.02  # 20ms

    # Maximum absolute sample value before clipping
    MAX_SAMPLE = 1.0

    def initialize gen, frameSize=2**12, gain=1.0
      @synth = gen
      @gain  = gain
      @muted = false
      @fade_gain = 1.0
      @fading_out = false
      @fading_in = false
      @clip_warning = true  # Warn on clipping
      @clipped = false
      @fade_samples = (FADE_TIME * @synth.srate).to_i
      raise ArgumentError, "#{synth.class} doesn't respond to ticks!" unless @synth.respond_to?(:ticks)
      init!( frameSize )
      start
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
      if @muted && @fade_gain <= 0.0 && !@fading_in
        out = Array.zeros( framesPerBuffer )
      else
        out = @synth.ticks( framesPerBuffer )
        out *= @gain unless @gain == 1.0

        # Apply fade-out/fade-in
        if @fading_out || @fading_in || @fade_gain < 1.0
          fade_delta = 1.0 / @fade_samples
          out = out.to_a.map.with_index do |sample, i|
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
          end.to_v
        end
      end

      # Hard clip to prevent extreme values
      clipped_this_frame = false
      out = out.to_a.map do |s|
        if s > MAX_SAMPLE
          clipped_this_frame = true
          MAX_SAMPLE
        elsif s < -MAX_SAMPLE
          clipped_this_frame = true
          -MAX_SAMPLE
        else
          s
        end
      end

      # Optional warning (only once per clip event)
      if @clip_warning && clipped_this_frame && !@clipped
        warn "AudioStream: clipping detected!"
        @clipped = true
      elsif !clipped_this_frame
        @clipped = false
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
      open( input, output, @synth.srate.to_i, frameSize )

      at_exit do
        close
        API.Pa_Terminate
      end
    end

  end
end
