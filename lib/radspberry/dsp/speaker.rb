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
      frame_size = opts[:frameSize]
      @@stream = frame_size ? AudioStream.new(_synth, frame_size) : AudioStream.new(_synth)
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
    attr_accessor :gain, :muted, :synth
  
    def initialize gen, frameSize=2**12, gain=1.0  # 1024
      @synth = gen # responds to tick
      @gain  = gain
      @muted = false
      raise ArgumentError, "#{synth.class} doesn't respond to ticks!" unless @synth.respond_to?(:ticks)
      init!( frameSize )
      start
    end

    def process input, output, framesPerBuffer, timeInfo, statusFlags, userData
      # inp = input.read_array_of_int16(framesPerBuffer)
      if @muted
        out = Array.zeros( framesPerBuffer )
      else
        out = @synth.ticks( framesPerBuffer )
        out *= @gain unless gain == 1.0
      end
      output.write_array_of_float out.to_a
      :paContinue
    end

    def init! frameSize=nil
      API.Pa_Initialize

      # input = API::PaStreamParameters.new
      # input[:device] = API.Pa_GetDefaultInputDevice
      # input[:sampleFormat] = API::Float32
      # input[:suggestedLatency] = API.Pa_GetDeviceInfo( input[:device ])[:defaultLowInputLatency]
      # input[:hostApiSpecificStreamInfo] = nil
      # input[:channelCount] = 1 #2; 

      input = nil
    
      output = API::PaStreamParameters.new
      output[:device]                    = API.Pa_GetDefaultOutputDevice
      output[:suggestedLatency]          = API.Pa_GetDeviceInfo(output[:device])[:defaultHighOutputLatency]
      output[:hostApiSpecificStreamInfo] = nil
      output[:channelCount]              = 1 #2; 
      output[:sampleFormat]              = API::Float32
      open( input, output, @synth.srate.to_i, frameSize )

      at_exit do
        # puts "#{self.class} terminating! closing PortAudio stream..."
        close
        API.Pa_Terminate
        # puts "done!"
      end
    end  
  
  end
end