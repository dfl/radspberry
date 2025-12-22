module DSP
  class PhasorOscillator < Oscillator
    param_accessor :phase, :delegate => :phasor
    param_accessor :freq,  :delegate => :phasor, :range => false # no range check for faster modulation

    def initialize( freq = DEFAULT_FREQ, phase=0 )
      @phasor = Phasor.new( freq, phase )
      clear!
    end

    def clear!
      self
    end

    def tock
      @phasor.phase.tap{ @phasor.tick }
    end

    def srate= rate
      super
      @phasor.srate = rate
    end
  end

  class Tri < PhasorOscillator
    FACTOR = { true => 1.0, false => -1.0 }

    def initialize( freq = DEFAULT_FREQ, phase=0 )
      super
    end

    def tick
      idx = phase < 0.5
      4*( FACTOR[idx]*tock + Phasor::OFFSET[idx] ) - 1
    end
  end

  class Pulse < PhasorOscillator
    param_accessor :duty, :default => 0.5

    FACTOR = { true => 1.0, false => -1.0 }

    def initialize( freq = DEFAULT_FREQ, phase=0 )
      super
    end
  
    def tick
      FACTOR[ tock <= @duty ]
    end
  end

  class RpmSaw < PhasorOscillator
    include DSP::Math
    param_accessor :beta, :range => (0..2), :default => 1.5

    RPM_CUTOFF = 5000.0  # Fixed cutoff for sample-rate independence

    def initialize( freq = DEFAULT_FREQ, phase=0 )
      self.beta= self.beta  # hack to init default
      @alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      super
    end

    def clear!
      @state = @last_out = 0
    end

    def tick
      @state += @alpha * (@last_out - @state)  # one-pole averager (5kHz cutoff)
      @last_out = sin( TWO_PI * tock + @beta * @state )
    end

    def srate= rate
      super
      @alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
    end
  end

  class RpmSquare < RpmSaw
    def initialize( freq = DEFAULT_FREQ, phase=0 )
      super
    end

    def tick
      @state += @alpha * (@last_out * @last_out - @state)  # one-pole averager, squared
      @last_out = sin( TWO_PI * tock - @beta * @state )
    end
  end

  class RpmNoise < PhasorOscillator
    include DSP::Math
    # param_accessor :beta, :default => 1234 # no range clamping

    def initialize( seed = 1234 )
      @beta = seed # || self.beta
      super
    end

    def clear!
      @last_out = 0
    end
  
    def tick
      @last_out = sin( TWO_PI * tock + @beta * @last_out )
    end

  end
  
end