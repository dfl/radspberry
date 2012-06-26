# require './math'

module DSP

  class Base
    include DSP::Constants

    class_attribute :srate
    class_attribute :inv_srate

    def sampleRate
      self.class.srate
    end

    def srate= arg
      raise "can't change instance srate"
    end

    def self.sampleRate
      self.srate
    end

    def self.sampleRate= f
      self.srate = f
      self.inv_srate = 1.0 / f
    end

    def clear
    end

    # allows for setting multiple values at once
    def [] args={}
      args.each_pair{ |k,v| send "#{k}=", v }
    end
  end

  Base.sampleRate = 44.1e3 # default

  class Generator < Base
    def tick
      raise "not implemented!"
    end

    def ticks samples, kperiod=nil
      raise ArgumentError, "must pass block along with kperiod" if kperiod && !block_given?
      if kperiod && kperiod < samples
        [].tap do |output|
          samples.in_groups_of( kperiod, 0.0 ) do |frame|
            yield( self )
            output += self.ticks(kperiod).to_a  # concat frames
          end
        end.to_v
      else
        samples.times.map{ tick }.to_v
      end
    end

    def to_wav( seconds, filename=nil )
      filename ||= "#{self.class}.wav"    
      filename += ".wav" unless filename =~ /\.wav$/i
      RiffFile.new(filename,"wb+") do |wav|
        samples = self.sampleRate * seconds
        if block_given?
          inv = 1.0 / samples
          data = samples.times.map{ |s| yield(self, s * inv); self.tick }
        else
          data = self.ticks( samples )
        end
        rescale = calc_sample_value(-0.5, 16) / [data.max, -data.max].max  # normalize to -0.5dBfs
        data.map!{|d| (d*rescale).round.to_f.to_i }
        wav.write(1, self.sampleRate, 16, [data] )
      end
    end

  end

  class Processor < Base
    ANTI_DENORMAL = 1e-20

    def tick(s)
      raise "not implemented!"
    end

    def ticks inputs
      inputs.map{|s| tick(s) }
    end

  end

  class TickerChain < Base
    def initialize chain, gain=1.0
      @chain,@gain = chain,gain
      @chain.each{|o| raise ArgumentError, "#{o.class} is not tickable" unless o.respond_to?(:tick) }
    end

    def self.[] *chain
      new(chain)
    end
  end

  class ProcessorChain < TickerChain
    def tick input
      @gain * @chain.inject( input ){|x,o| o.tick(x) }
    end

    def ticks samples
      @gain * @chain.inject( Vector.zeros(samples) ){|x,o| o.ticks(x) }
    end
  end

  class Mixer < Generator
    def self.[] *mix
      new mix
    end

    def initialize mix
      raise ArugmentError, "must be array" unless mix.is_a?(Array)
      @mix  = mix
      @gain = 1.0 / Math.sqrt( @mix.size )
    end

    def tick
      @gain * @mix.tick_sum
    end

    def ticks samples
      @gain * @mix.ticks_sum( samples )
    end
  end

  class XFader < Generator
    param_accessor :fade

    def self.[] *mix
      new mix[0], mix[1], mix[2]
    end

    def initialize a, b,fade=nil
      raise ArgumentError, "inputs cannot be nil!" unless a && b
      @fade = fade || 0.5
      @a,@b = a,b
    end

    def tick
      DSP.xfade @a.tick, @b.tick, @fade
    end

    def ticks samples
      a = @a.ticks(samples)
      b = @b.ticks(samples)
      (b-a)*@fade + a  # TODO cos fade?
    end 

  end

  class GainMixer < Generator
    def self.[] *mix
      case mix
      when Hash
        new mix.keys, mix.values
      when Array
        new mix
      end
    end

    def initialize mix, gains=nil
      raise ArgumentError, "must be array" unless mix.is_a?(Array)
      @mix   = mix
      size   = @mix.size
      @gains = case gains
      when Float
        Array.full_of( gains )
      when Array
        raise ArgumentError, "gains array has wrong size" unless gains.size == size
        gains
      else
        Array.full_of( 1.0 / Math.sqrt( size ), size )
      end
    end

    def tick
      @mix.each_with_index.inject( 0.0 ){|sum,(o,i)| sum + @gains[i] * o.tick }
    end

    def ticks samples
      @mix.each_with_index.inject( Vector.zeros(samples) ){|sum,(o,i)| sum + @gains[i] * o.ticks(samples) }
    end
  end


  class GeneratorChain < TickerChain
    def initialize chain, gain=1.0
      super
      @gen = @chain.shift
      if @gen.is_a?(Array)
        @gen = Mixer[ @gen ]
      end
    end

    def tick
      @gain * @chain.inject( @gen.tick ){|x,o| o.tick(x) }
    end

    def ticks samples
      @gain * @chain.inject( @gen.ticks(samples) ){|x,o| o.ticks(x) }
    end
  end


  class Noise < Generator
    def tick
      DSP.noise
    end
  end

  class Oscillator < Generator
    attr_accessor :freq
    DEFAULT_FREQ = MIDI::A / 2

    def initialize freq=DEFAULT_FREQ
      self.freq = freq
    end
  end

  class Phasor < Oscillator
    attr_accessor :phase

    OFFSET = { true => 0.0, false => 1.0 }  # branchless trick from Urs Heckmann

    def initialize( freq = DEFAULT_FREQ, phase=nil )
      @phase = phase ? DSP.clamp( phase, 0, 1.0 ) : DSP.random
      super freq
    end

    def tick
      @phase += @inc                     # increment
      @phase -= OFFSET[ @phase <= 1.0 ]  # wrap
    end

    def freq= arg
      @freq = arg
      @inc  = @freq * inv_srate
    end
  end

  class Decimator < Phasor
    def tick input
      @phase += @inc              # increment
      nowrap = @phase <= 1.0
      @phase -= OFFSET[ nowrap ]  # wrap
      nowrap ? @last : @last=input
    end

  end

  class LFO < Oscillator

  end

  class SampleHold < LFO
    def initialize freq = DEFAULT_FREQ, phase = DSP.random
      @latch = Decimator.new( freq, phase )
    end

    def freq= arg
      @latch.freq = arg
    end

    def tick
      @latch.tick( DSP.noise )
    end
  end

  class Spicer < Processor
    include DSP::Math

    def tick input
      sin( input )      
    end    
  end
  
  class SampleGlide < SampleHold
    def initialize freq = DEFAULT_FREQ, phase = DSP.random
      @slew = Lowpass.new( 0.5/freq )
    end

    def tick
      @slew.tick( super )
    end
  end

  class OnePole < Processor 
    def initialize
      @gain = @pole = 0
      clear
    end

    def clear
      @last_out = 0
    end

    def tick input
      @last_out = @gain*input + @pole*@last_out
    end
  end


  class Contour < Processor
    def initialize contour
      self.contour = contour
      clear
    end

    def contour= c
      @pole = DSP.clamp(-c,-1.0,1.0);
      @gain = 1.0 - @contour.abs
    end
  end

  class Lowpass < OnePole  # envelope smoother, etc.
    def initialize tau
      tau = tau
      clear
    end

    def tau= tau
      @alpha = inv_srate / ( tau + inv_srate )
      @gain = @alpha
      @pole = 1-@alpha
    end
  end

  class DcBlocker < Processor    #http://www-ccrma.stanford.edu/~jos/filters/
    def initialize f=30
      @r = 1 - (TWO_PI * @f * inv_srate)
      clear
    end
    def clear
      @last_in  = 0
      @last_out = 0
    end
    def tick input
      @last_out = input - @last_in + @r * @last_out.tap{ @last_in = input }
    end
  end

end