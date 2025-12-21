module DSP

  # based on Adam Szabo's thesis from csc.kth.se
  class SuperSaw < Oscillator
    param_accessor :spread, :default => 0.5, :after_set => Proc.new{detune_phasors}
    param_accessor :mix,    :default => 0.75

    # Normalization factor to keep output in [-1, 1] range
    # Phasors are centered (-0.5 to 0.5), and we sum 7 of them with mixing coefficients
    # At mix=0.75: center~0.58, side~0.59, worst case peak ~2.0
    # We use 0.5 to bring typical peaks to reasonable levels
    NORMALIZE = 0.5

    def initialize freq = DEFAULT_FREQ
      @master  = Phasor.new
      setup_tables
      @phasors = @@offsets.size.times.map{ Phasor.new }
      randomize_phase
      @spread   = self.spread # set default
      @mix      = self.mix
      self.freq = freq
    end

    def randomize_phase
      @master.phase = DSP.random
      @phasors.each{|p| p.phase = DSP.random }
    end

    def clear!  # call this on note on
      randomize_phase
    end

    def freq= f
      @master.freq = @freq = f
      detune_phasors
    end

    def tick
      # Center phasors from 0-1 to -0.5 to 0.5 range to eliminate DC
      osc =  @@center[ @mix ] * (@master.tick - 0.5)
      @phasors.each { |p| osc += @@side[ @mix ] * (p.tick - 0.5) }
      NORMALIZE * osc
    end

    def ticks samples
      # Center phasors from 0-1 to -0.5 to 0.5 range to eliminate DC
      osc = @@center[ @mix ] * (@master.ticks(samples) - Vector.elements([0.5] * samples))
      @phasors.each do |p|
        osc += @@side[ @mix ] * (p.ticks(samples) - Vector.elements([0.5] * samples))
      end
      NORMALIZE * osc
    end
    
    private 

    def detune_phasors
      @phasors.each_with_index{|p,i| p.freq = (1 + @@detune[@spread] * @@offsets[i]) * @freq }
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
      -0.73764*x*x + 1.2841*x + 0.044372
    end

    def calc_center x
      -0.55366*x + 0.99785
    end

  end

end