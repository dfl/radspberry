# based on Adam Szabo's thesis from csc.kth.se
class SuperSaw < Oscillator
  attr_accessor :spread

  def initialize freq = DEFAULT_FREQ, spread=0.5, num=7
    @master = Phasor.new
    @phasors = (1..num-1).map{ Phasor.new }
    @spread = spread
    setup_tables
    @hpf = Hpf.new( @master.freq )
    randomize_phase
    self.freq = freq
  end

  def spread= x
    @spread = x
    detune_phasors
  end
    
  def randomize_phase
    @phasors.each{|p| p.phase = DSP.random }
  end
  
  def clear
    @hpf.clear
    randomize_phase
  end
  
  def freq= f
    @hpf.freq = @master.freq = @freq = f
    detune_phasors
  end

  def tick
    osc =  @@center[ @spread ] * @master.tick
    osc +=   @@side[ @spread ] * @phasors.inject(0){|sum,p| sum + p.tick }
    @hpf.tick( osc )
  end
  
  def ticks samples
    osc =  @@center[ @spread ] * Vector[*@master.ticks(samples)]
    osc =    @@side[ @spread ] * @phasors.inject( osc ){|sum,p| sum + Vector[*p.ticks(samples)] }
    @hpf.ticks( osc.to_a )
  end
    
  private 

  def detune_phasors
    @phasors.each_with_index{ |p,i| p.freq = (1 + @@detune[@spread] * @@offsets[i]) * @freq }
  end

  def setup_tables
    @@offsets ||= [ -0.11002313, -0.06288439, -0.01952356, 0.01991221, 0.06216538, 0.10745242 ]
    @@detune  ||= DSP::LookupTable.new{|x| calc_detune(x) }
    @@side    ||= DSP::LookupTable.new{|x| calc_side(x)   }
    @@center  ||= DSP::LookupTable.new{|x| calc_center(x) }
  end
  
  def calc_detune x
    1.0 - (1.0-x) ** 0.2
  end
  
  def calc_side x
    -0.73754*x*x + 1.2841*x + 0.044372
  end

  def calc_center x
    -0.55366*x + 0.99785
  end

end