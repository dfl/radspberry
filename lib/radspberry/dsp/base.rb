# require './math'

module DSP

  class Base
    include DSP::Constants

    class_attribute :srate
    class_attribute :inv_srate

    def sample_rate
      self.class.srate
    end

    def srate= arg
      raise "can't change instance srate"
    end

    def self.sample_rate
      self.srate
    end

    def self.sample_rate= f
      self.srate = f
      self.inv_srate = 1.0 / f
    end

    def clear!
    end

    # allows for setting multiple values at once
    def [] args={}
      args.each_pair{ |k,v| send "#{k}=", v }
    end

    def calc_sample_value(db, bits)
      # Calculate sample value for given dBFS and bit depth
      # db is in dBFS (negative for below full scale)
      # bits is bit depth (e.g., 16 for 16-bit PCM)
      max_value = 2 ** (bits - 1) - 1
      linear_scale = 10.0 ** (db / 20.0)
      max_value * linear_scale
    end
  end

  Base.sample_rate = 44.1e3 # default

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

    # Enable function composition with >> operator
    def >> (other)
      case other
      when Processor, ProcessorChain
        GeneratorChain.new([self, other])
      when Module  # Check if it's the Speaker module
        other[self] if other.respond_to?(:[])
        self
      else
        # Duck-type check for Processor-like objects (e.g. ModulatedProcessor)
        if other.respond_to?(:tick) && other.method(:tick).arity != 0
          GeneratorChain.new([self, other])
        else
          raise ArgumentError, "Can only compose Generator with Processor, ProcessorChain, or Speaker"
        end
      end
    end

    # Parallel composition
    def + (other)
      Mixer.new([self, other])
    end

    # Signal subtraction
    def - (other)
      Mixer.new([self, other * -1.0])
    end

    # Gain control operators
    def * (gain)
      GeneratorChain.new([self], gain)
    end

    def / (gain)
      GeneratorChain.new([self], 1.0 / gain)
    end

    # Crossfade composition
    def crossfade(other, fade = 0.5)
      XFader.new(self, other, fade)
    end

    def to_wav( seconds, filename: nil, channels: :mono)
      filename ||= "#{self.class}.wav"
      filename += ".wav" unless filename =~ /\.wav$/i

      samples = (self.sample_rate * seconds).to_i
      if block_given?
        inv = 1.0 / samples
        data = samples.times.map{ |s| yield(self, s * inv); self.tick }
      else
        data = self.ticks( samples )
      end

      data = data.to_a if data.is_a?(Vector)
      rescale = calc_sample_value(-0.5, 16) / [data.max, -data.min].max  # normalize to -0.5dBfs
      data.map!{|d| (d*rescale).round.to_i }

      format = WaveFile::Format.new(channels, :pcm_16, self.sample_rate.to_i)
      buffer = WaveFile::Buffer.new(data, format)

      WaveFile::Writer.new(filename, format) do |writer|
        writer.write(buffer)
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

    # Enable function composition with >> operator
    def >> (other)
      case other
      when Processor, ProcessorChain
        ProcessorChain.new([self, other])
      else
        raise ArgumentError, "Can only compose Processor with another Processor or ProcessorChain"
      end
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
      @gain * @chain.reduce(input) { |signal, processor| processor.tick(signal) }
    end

    def ticks samples
      @gain * @chain.reduce(samples) { |signal, processor| processor.ticks(signal) }
    end

    # Enable further composition
    def >> (other)
      case other
      when Processor
        ProcessorChain.new(@chain + [other], @gain)
      when ProcessorChain
        ProcessorChain.new(@chain + other.instance_variable_get(:@chain), @gain)
      else
        raise ArgumentError, "Can only compose ProcessorChain with Processor or ProcessorChain"
      end
    end
  end

  class Mixer < Generator
    def self.[] *mix
      new mix
    end

    def initialize mix, gain_multiplier=1.0
      raise ArugmentError, "must be array" unless mix.is_a?(Array)
      @mix  = mix
      @base_gain = 1.0 / ::Math.sqrt( @mix.size )
      @gain_multiplier = gain_multiplier
      @gain = @base_gain * @gain_multiplier
    end

    def tick
      @gain * @mix.tick_sum
    end

    def ticks samples
      @gain * @mix.ticks_sum( samples )
    end

    # Allow adding more sources to the mix
    def + (other)
      Mixer.new(@mix + [other], @gain_multiplier)
    end

    # Gain control operators
    def * (gain)
      Mixer.new(@mix, @gain_multiplier * gain)
    end

    def / (gain)
      Mixer.new(@mix, @gain_multiplier / gain)
    end

    # Delegate unknown methods to all generators in the mix
    # Setters (methods ending with =) are called on all, getters return from first
    def method_missing(method, *args, &block)
      if method.to_s.end_with?('=')
        # Setter: apply to all generators that respond to it
        @mix.each do |gen|
          gen.send(method, *args, &block) if gen.respond_to?(method)
        end
      elsif @mix.first.respond_to?(method)
        # Getter: return from first generator
        @mix.first.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @mix.any? { |gen| gen.respond_to?(method, include_private) } || super
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
        Array.full_of( 1.0 / ::Math.sqrt( size ), size )
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
      @gain * @chain.reduce(@gen.tick) { |signal, processor| processor.tick(signal) }
    end

    def ticks samples
      @gain * @chain.reduce(@gen.ticks(samples)) { |signal, processor| processor.ticks(signal) }
    end

    # Enable further composition
    def >> (other)
      case other
      when Processor, ProcessorChain
        GeneratorChain.new([@gen] + @chain + [other], @gain)
      when Module  # Speaker module
        other[self] if other.respond_to?(:[])
        self
      else
        raise ArgumentError, "Can only compose GeneratorChain with Processor, ProcessorChain, or Speaker"
      end
    end

    # Parallel composition
    def + (other)
      Mixer.new([self, other])
    end

    # Signal subtraction
    def - (other)
      Mixer.new([self, other * -1.0])
    end

    # Gain control operators
    def * (gain)
      GeneratorChain.new([@gen] + @chain, @gain * gain)
    end

    def / (gain)
      GeneratorChain.new([@gen] + @chain, @gain / gain)
    end

    # Crossfade composition
    def crossfade(other, fade = 0.5)
      XFader.new(self, other, fade)
    end

    def to_wav( seconds, filename: nil, channels: :mono)
      filename ||= "#{self.class}.wav"
      filename += ".wav" unless filename =~ /\.wav$/i

      samples = (self.sample_rate * seconds).to_i
      if block_given?
        inv = 1.0 / samples
        data = samples.times.map{ |s| yield(self, s * inv); self.tick }
      else
        data = self.ticks( samples )
      end

      data = data.to_a if data.is_a?(Vector)
      rescale = calc_sample_value(-0.5, 16) / [data.max, -data.min].max  # normalize to -0.5dBfs
      data.map!{|d| (d*rescale).round.to_i }

      format = WaveFile::Format.new(channels, :pcm_16, self.sample_rate.to_i)
      buffer = WaveFile::Buffer.new(data, format)

      WaveFile::Writer.new(filename, format) do |writer|
        writer.write(buffer)
      end
    end

    # Delegate unknown methods to the wrapped generator
    def method_missing(method, *args, &block)
      if @gen.respond_to?(method)
        @gen.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @gen.respond_to?(method, include_private) || super
    end
  end


  class Noise < Generator
    def tick
      DSP.noise
    end
  end

  class Oscillator < Generator
    attr_reader :freq
    DEFAULT_FREQ = MIDI::A / 2

    def initialize freq=DEFAULT_FREQ
      self.freq = freq
    end

    def freq=(val)
      @freq = DSP.to_freq(val)
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
      @phase += @inc
      @phase -= 1.0 if @phase >= 1.0
      @phase
    end

    def freq= arg
      @freq = DSP.to_freq(arg)
      @inc  = @freq * inv_srate
    end
  end

  class Decimator < Phasor
    def tick input
      @phase += @inc
      if @phase <= 1.0
        @last
      else
        @phase -= 1.0
        @last = input
      end
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
      clear!
    end

    def clear!
      @last_out = 0
    end

    def tick input
      @last_out = @gain*input + @pole*@last_out
    end
  end


  class Contour < Processor
    def initialize contour
      self.contour = contour
      clear!
    end

    def contour= c
      @pole = DSP.clamp(-c,-1.0,1.0);
      @gain = 1.0 - @contour.abs
    end
  end

  class Lowpass < OnePole  # envelope smoother, etc.
    def initialize tau
      tau = tau
      clear!
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
      clear!
    end
    def clear!
      @last_in  = 0
      @last_out = 0
    end
    def tick input
      @last_out = input - @last_in + @r * @last_out.tap{ @last_in = input }
    end
  end

end