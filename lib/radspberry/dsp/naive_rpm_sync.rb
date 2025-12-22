module DSP

  # Naive hard sync RPM oscillator - direct translation of hardsync.pd
  #
  # Simple hard sync: master phasor × ratio → wrap → RPM
  # No anti-aliasing windowing (unlike DualRPMOscillator)
  #
  # Good for: learning, low CPU, lo-fi aesthetic
  # Bad for: high sync ratios (aliasing), clean sounds
  class NaiveRpmSync < Oscillator
    include DSP::Math

    RPM_CUTOFF = 5000.0  # Fixed cutoff for sample-rate independence

    param_accessor :sync_ratio, :default => 2.0,  :range => (0.1..32.0)
    param_accessor :index,      :default => 1.0,  :range => (0.0..10.0)  # FM index for RPM
    param_accessor :exponent,   :default => 1.5,  :range => (0.0..4.0)   # RPM beta/exponent

    def initialize(freq = DEFAULT_FREQ)
      @sync_ratio = 2.0
      @index = 1.0
      @exponent = 1.5
      @alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @master_inc = @freq * inv_srate
    end

    def clear!
      @master_phase = 0.0
      @rpm_state = 0.0
      @rpm_last_out = 0.0
    end

    def tick
      # 1. Calculate slave phase (master × ratio, wrapped)
      slave_phase = (@master_phase * @sync_ratio) % 1.0

      # 2. RPM oscillator with the wrapped phase
      # State update: one-pole averager (5kHz cutoff)
      @rpm_state += @alpha * (@rpm_last_out - @rpm_state)

      # Output: sin(2π × phase + beta × state)
      @rpm_last_out = sin(TWO_PI * slave_phase + @exponent * @rpm_state)

      # 3. Advance master phase
      @master_phase += @master_inc
      @master_phase -= 1.0 if @master_phase >= 1.0

      @rpm_last_out
    end
  end


  # Extended naive sync with index modulation (closer to rpmb~ behavior)
  # The index parameter modulates both the sync ratio and RPM feedback
  class NaiveRpmSyncIndexed < Oscillator
    include DSP::Math

    RPM_CUTOFF = 5000.0  # Fixed cutoff for sample-rate independence

    param_accessor :sync_ratio, :default => 2.0,  :range => (0.1..32.0)
    param_accessor :index,      :default => 1.0,  :range => (0.0..10.0)
    param_accessor :exponent,   :default => 1.5,  :range => (0.0..4.0)

    def initialize(freq = DEFAULT_FREQ)
      @sync_ratio = 2.0
      @index = 1.0
      @exponent = 1.5
      @alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @master_inc = @freq * inv_srate
    end

    def clear!
      @master_phase = 0.0
      @rpm_state = 0.0
      @rpm_last_out = 0.0
    end

    def tick
      # Effective ratio modulated by index
      eff_ratio = @sync_ratio * @index

      # 1. Calculate slave phase
      slave_phase = (@master_phase * eff_ratio) % 1.0

      # 2. RPM with index-scaled feedback (5kHz cutoff)
      @rpm_state += @alpha * (@rpm_last_out - @rpm_state)
      eff_beta = @exponent * @index
      @rpm_last_out = sin(TWO_PI * slave_phase + eff_beta * @rpm_state)

      # 3. Advance master
      @master_phase += @master_inc
      @master_phase -= 1.0 if @master_phase >= 1.0

      @rpm_last_out
    end
  end


  # Naive sync with morphable RPM waveform (saw ↔ square)
  # Matches the morph behavior from DualRPMOscillator::RPM
  class NaiveRpmSyncMorph < Oscillator
    include DSP::Math

    RPM_CUTOFF = 5000.0  # Fixed cutoff for sample-rate independence

    param_accessor :sync_ratio, :default => 2.0,  :range => (0.1..32.0)
    param_accessor :beta,       :default => 1.5,  :range => (0.0..2.0)
    param_accessor :morph,      :default => 0.0,  :range => (0.0..1.0)  # 0=saw, 1=square-ish

    def initialize(freq = DEFAULT_FREQ)
      @sync_ratio = 2.0
      @beta = 1.5
      @morph = 0.0
      @alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @master_inc = @freq * inv_srate
    end

    def clear!
      @master_phase = 0.0
      @rpm_state = 0.0
      @rpm_last_out = 0.0
    end

    def tick
      # 1. Calculate slave phase
      slave_phase = (@master_phase * @sync_ratio) % 1.0

      # 2. Morphable RPM
      # Feedback signal morphs between linear and squared
      fb_signal = (@rpm_last_out * @rpm_last_out - @rpm_last_out) * @morph + @rpm_last_out
      @rpm_state += @alpha * (fb_signal - @rpm_state)  # one-pole averager (5kHz cutoff)

      # Beta scales inversely with morph for balanced timbre
      eff_beta = @beta * (1.0 - 2.0 * @morph)
      @rpm_last_out = sin(TWO_PI * slave_phase + eff_beta * @rpm_state)

      # 3. Advance master
      @master_phase += @master_inc
      @master_phase -= 1.0 if @master_phase >= 1.0

      @rpm_last_out
    end
  end

end
