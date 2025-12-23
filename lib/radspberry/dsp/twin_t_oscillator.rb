module DSP
  # Twin-T Oscillator
  # Models the TR-808's bridged-T network oscillator used in kick and toms.
  # Key characteristics:
  # - Coupled pitch and decay (higher freq = faster decay)
  # - Pitch sweep with damped resonance
  # - Slight pitch instability/drift
  class TwinTOscillator < Oscillator
    include DSP::Math
    
    attr_accessor :damping, :coupling, :drift, :drop
    
    def initialize(freq: 50, damping: 0.8, coupling: 1.0, drift: 0.0, drop: 1.05)
      @freq = freq
      @damping = damping               # Base amplitude decay rate  
      @coupling = coupling             # 0-1: how much decay time scales with freq
      @drift = drift                   # Pitch instability amount
      @drop = drop                     # Subtle pitch drop factor (e.g. 1.05 = 5% drop)
      
      super(@freq)
      clear!
    end
    
    def clear!
      @time = 0.0
      @drift_phase = 0.0
      @phase = 0.0
    end
    
    def trigger!
      clear!
    end
    
    def tick
      # Subtle pitch drop: frequency is higher at the start of the impulse 
      # and settles to @freq as energy dissipates.
      # We use the damping itself to drive this "natural" drop.
      current_freq = @freq * (1.0 + (@drop - 1.0) * ::Math.exp(-@time * @damping * 2.0))
      
      # Frequency-dependent decay time (Twin-T coupling)
      freq_ratio = @freq / [current_freq, 1.0].max
      decay_scale = freq_ratio ** @coupling
      effective_damping = @damping / decay_scale
      
      # Amplitude envelope
      amp_env = ::Math.exp(-@time * effective_damping)
      
      # Slight pitch drift
      @drift_phase += @drift * DSP.noise * 0.01
      freq_with_drift = current_freq * (1.0 + @drift_phase)
      
      # Phase generation
      phase_inc = freq_with_drift * inv_srate
      @phase = (@phase + phase_inc) % 1.0
      
      output = sin(TWO_PI * @phase) * amp_env
      
      @time += inv_srate
      output
    end
    
    def srate= rate
      super
      clear!
    end
  end
end
