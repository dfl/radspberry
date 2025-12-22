module DSP

  # based on Adam Szabo's thesis from csc.kth.se
  class SuperSaw < Oscillator
    param_accessor :spread, :default => 0.5, :after_set => Proc.new{detune_phasors}
    param_accessor :mix,    :default => 0.75
    
    attr_accessor :polyblep

    # Normalization factor (unchanged)
    NORMALIZE = 0.5

    def initialize freq = DEFAULT_FREQ, polyblep: false
      @master  = Phasor.new
      setup_tables
      @phasors = @@offsets.size.times.map{ Phasor.new }
      randomize_phase
      @spread   = self.spread # set default
      @mix      = self.mix
      @polyblep = polyblep
      
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
      @master.freq = @freq = DSP.to_freq(f)
      detune_phasors
    end
    
    def calc_polyblep(phase, inc)
      dt = inc
      
      # 0 <= phase < 1
      if phase < dt
        t = phase / dt
        return 2.0 * t - t * t - 1.0
      elsif phase > 1.0 - dt
        t = (phase - 1.0) / dt
        return 2.0 * t + t * t + 1.0
      end
      
      0.0
    end

    def tick_osc(phasor)
      # Capture phase BEFORE increment for correct PolyBLEP application
      phase_before = phasor.phase
      inc = phasor.freq * phasor.inv_srate
      
      # Naive saw: phase - 0.5 (range -0.5 to 0.5)
      raw = phasor.tick - 0.5
      
      if @polyblep
        # Apply PolyBLEP correction at the discontinuity
        raw -= calc_polyblep(phase_before, inc)
      end
      raw
    end

    def tick
      # Master
      osc = @@center[ @mix ] * tick_osc(@master)
      
      # Side phasors
      @phasors.each { |p| osc += @@side[ @mix ] * tick_osc(p) }
      
      NORMALIZE * osc
    end

    def ticks samples
      return super(samples) if @polyblep
      
      # Center phasors from 0-1 to -0.5 to 0.5 range to eliminate DC
      osc = @@center[ @mix ] * (@master.ticks(samples) - Vector.elements([0.5] * samples))
      @phasors.each do |p|
        osc += @@side[ @mix ] * (p.ticks(samples) - Vector.elements([0.5] * samples))
      end
      NORMALIZE * osc
    end
    
    def srate= rate
      super
      @master.srate = rate
      @phasors.each { |p| p.srate = rate }
    end

    def clear!
      randomize_phase
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