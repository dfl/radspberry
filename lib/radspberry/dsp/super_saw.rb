module DSP

  # based on Adam Szabo's thesis from csc.kth.se
  class SuperSaw < Oscillator
    param_accessor :spread, :default => 0.5, :after_set => Proc.new{detune_phasors}
    param_accessor :mix,    :default => 0.75
    
    def initialize freq = DEFAULT_FREQ
      @master  = Phasor.new
      @hpf     = ButterHP.new( @master.freq )
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
  
    def clear  # call this on note on
      @hpf.clear
      randomize_phase
    end
  
    def freq= f
      @hpf.freq = @master.freq = @freq = f
      detune_phasors
    end

    def tick
      osc =  @@center[ @mix ] * @master.tick
      osc +=   @@side[ @mix ] * @phasors.tick_sum #inject(0){|sum,p| sum + p.tick }
      @hpf.tick( osc )
    end
  
    def ticks samples
      osc =  @@center[ @mix ] * @master.ticks(samples)
      osc =    @@side[ @mix ] * @phasors.ticks_sum( samples, osc ) #inject( osc ){|sum,p| sum + p.ticks(samples).to_v }
      @hpf.ticks( osc )
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