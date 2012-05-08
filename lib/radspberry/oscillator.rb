require './dsp'

class PhasorOscillator < Oscillator
  def initialize( freq = DEFAULT_FREQ, phase=0 )
    @phasor = Phasor.new( freq, phase )
    clear
    # super(freq)
  end

  def clear
  end

  def freq= arg
    @phasor.freq = arg
  end
  def phase= arg
    @phasor.phase = DSP.clamp(arg, 0.0, 1.0)
  end
  def phase
    @phasor.phase
  end    

  def tock
    @phasor.phase.tap{ @phasor.tick }
  end
end

class Tri < PhasorOscillator
  FACTOR = { true => 1.0, false => -1.0 }

  def tick
    idx = phase < 0.5
    4*( FACTOR[idx]*tock + Phasor::OFFSET[idx] ) - 1
  end
end

class Pulse < PhasorOscillator
  FACTOR = { true => 1.0, false => -1.0 }

  def initialize( freq=DEFAULT_FREQ, phase=0 )
    @duty = 0.5
    super
  end

  def duty= arg
    @duty = DSP.clamp(arg, 0.0, 1.0)
  end
  
  def tick
    FACTOR[ tock <= @duty ]
  end
end

class RpmSaw < PhasorOscillator
  include DSP::Math

  def initialize( freq=MIDI::A, phase = DSP.random )
    @beta = 1.5 # TODO: base on frequency?
    super
  end

  def clear
    @state = @last_out = 0
  end

  def beta= arg, clamp=true
    @beta = DSP.clamp(arg, 0.0, 2.0)
  end
  
  def tick
    @state = 0.5*(@state + @last_out) # one-pole averager
    @last_out = sin( TWO_PI * tock + @beta * @state )
  end
end

class RpmSquare < RpmSaw
  def tick
    @state = 0.5*(@state + @last_out*@last_out) # one-pole averager, squared
    @last_out = sin( TWO_PI * tock - @beta * @state )
  end
end

class RpmNoise < RpmSaw
  attr_accessor :beta
  def initialize( seed = 1234 )
    super()
    @beta = seed
  end

end    
