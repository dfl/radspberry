module DSP

  class DualRPMOscillator < Oscillator
    include DSP::Math

    # Parameters
    param_accessor :sync_ratio,      :default => 2.0,   :range => (0.1..20.0)
    # window_alpha: Controls the shape of the Kaiser window used to crossfade slave oscillators.
    #   - alpha > 0: Shaped Kaiser window (bell curve). Higher alpha = narrower window, smoother sound, less aliasing.
    #   - alpha = 0: Triangular window (linear crossfade). Brightest sound, most "transparent" windowing.
    # Note: Windowing is ALWAYS active to suppress hard sync discontinuities.
    param_accessor :window_alpha,    :default => 1.0,   :range => (0.0..10.0), :after_set => proc{generate_window}
    param_accessor :beta,            :default => 1.5,   :range => (0.0..5.0),  :after_set => proc{update_beta}
    param_accessor :morph,           :default => 0.0,   :range => (0.0..1.0),  :after_set => proc{update_morph}
    param_accessor :duty,            :default => 0.5,   :range => (0.01..0.99)
    
    # FM Parameters
    param_accessor :fm_ratio,        :default => 1.0,   :range => (0.1..10.0)
    param_accessor :fm_index,        :default => 0.0,   :range => (0.0..10.0)
    param_accessor :fm_linear_amt,   :default => 0.5,   :range => (0.0..1.0) # 0 = PM, 1 = Linear FM
    param_accessor :fm_feedback,     :default => 0.0,   :range => (-2.0..2.0)

    # Inharmonicity: curvature-based frequency modulation (piano-like stretched partials)
    param_accessor :inharmonicity,   :default => 0.0,   :range => (0.0..0.1), :after_set => proc{update_inharmonicity}

    WINDOW_SIZE = 1024

    # Inner RPM core - single mode (saw or square) with own feedback
    class RPMCore
      include DSP::Math
      attr_accessor :beta, :inharmonicity
      attr_reader :freq_mult, :last_out

      POWER_ALPHA = 0.001
      CURV_ALPHA = 0.001

      def initialize(mode, beta = -1.5)
        @mode = mode  # :saw or :square
        @beta = beta
        @inharmonicity = 0.0
        clear!
      end

      def clear!
        @last_out = 0.0
        @last_out_prev = 0.0
        @last_out_prev2 = 0.0
        @rms_sq = 0.5
        @curv_rms = 0.01
        @freq_mult = 1.0
      end

      def process(phase)
        # Inharmonicity
        curv = @last_out - 2.0 * @last_out_prev + @last_out_prev2
        @curv_rms += CURV_ALPHA * (curv * curv - @curv_rms)
        curv_norm = curv / ::Math.sqrt([@curv_rms, 1e-6].max)
        @freq_mult = 1.0 + @inharmonicity * curv_norm * curv_norm

        y = (@mode == :saw) ? process_saw(phase) : process_square(phase)

        @last_out_prev2 = @last_out_prev
        @last_out_prev = @last_out
        @last_out = y
        y
      end

      private

      def process_saw(phase)
        y_avg = 0.5 * (@last_out + @last_out_prev)
        y_sq = @last_out * @last_out
        @rms_sq += POWER_ALPHA * (y_sq - @rms_sq)
        rms = ::Math.sqrt([@rms_sq, 0.01].max)
        u = -@beta * 0.5 * (y_avg / rms)
        sin(DSP::TWO_PI * phase + u)
      end

      def process_square(phase)
        ysq_avg = 0.5 * (@last_out * @last_out + @last_out_prev * @last_out_prev)
        @rms_sq += POWER_ALPHA * (ysq_avg - @rms_sq)
        u = -@beta * (ysq_avg / [@rms_sq, 0.01].max * 0.5 - 0.5)
        sin(DSP::TWO_PI * phase + u)
      end
    end

    # Dual RPM with morphing - holds both saw and square oscillators
    class RPMDual
      attr_accessor :beta, :morph, :inharmonicity
      attr_reader :freq_mult, :last_out

      def initialize(beta = -1.5)
        @beta = beta
        @morph = 0.0
        @inharmonicity = 0.0
        @saw = RPMCore.new(:saw, @beta)
        @sqr = RPMCore.new(:square, @beta)
      end

      def clear!
        @saw.clear!
        @sqr.clear!
      end

      def beta=(val)
        @beta = val
        @saw.beta = @beta
        @sqr.beta = @beta
      end

      def inharmonicity=(val)
        @inharmonicity = val
        @saw.inharmonicity = val
        @sqr.inharmonicity = val
      end

      def process(phase)
        y_saw = @saw.process(phase)
        y_sqr = @sqr.process(phase)
        @last_out = (1.0 - @morph) * y_saw + @morph * y_sqr
        @freq_mult = @saw.freq_mult  # Use saw's freq_mult for inharmonicity
        @last_out
      end
    end

    def initialize(freq = DEFAULT_FREQ)
      @fm_ratio = 1.0
      @sync_ratio = 2.0
      @window_alpha = 1.0
      @beta = 1.5
      @morph = 0.0
      @duty = 0.5
      @fm_index = 0.0
      @fm_linear_amt = 0.5
      @fm_feedback = 0.0
      @inharmonicity = 0.0

      super freq

      @master_osc = RPMDual.new(@beta)
      @slave_osc1 = RPMDual.new(@beta)
      @slave_osc2 = RPMDual.new(@beta)
      @fm_mod_osc = RPMCore.new(:saw, 0.0)  # FM modulator doesn't need morph

      @master_phase = 0.0
      @fm_mod_phase = 0.0
      
      @last_master_out = 0.0
      @last_slave_out1 = 0.0
      @last_slave_out2 = 0.0
      @last_fm_mod_out = 0.0

      # Generate window with initial alpha
      generate_window
    end

    def clear!
      @master_phase = 0.0
      @fm_mod_phase = 0.0
      @last_master_out = 0.0
      @last_slave_out1 = 0.0
      @last_slave_out2 = 0.0
      @last_fm_mod_out = 0.0
      @master_osc.clear!
      @slave_osc1.clear!
      @slave_osc2.clear!
      @fm_mod_osc.clear!
    end

    def freq=(f)
      @freq = f.to_f
      @master_inc = @freq * inv_srate
      update_fm_inc
    end

    def fm_ratio=(r)
      @fm_ratio = r
      update_fm_inc
    end

    def tick
      # 1. Update FM modulator
      @fm_mod_phase += @fm_mod_inc
      @fm_mod_phase -= 1.0 if @fm_mod_phase >= 1.0
      @last_fm_mod_out = @fm_mod_osc.process(@fm_mod_phase)

      # 2. Calculate master phase modulation (Feedback from slaves)
      master_pm = 0.0
      if @fm_feedback != 0.0
        slave_avg = 0.5 * (@last_slave_out1 + @last_slave_out2)
        master_pm = slave_avg * @fm_feedback
      end

      # 3. Generate master oscillator output
      eff_master_phase = @master_phase + master_pm
      # PM can be large, use while or if if it's constrained
      if eff_master_phase >= 1.0
        eff_master_phase -= 1.0 while eff_master_phase >= 1.0
      elsif eff_master_phase < 0.0
        eff_master_phase += 1.0 while eff_master_phase < 0.0
      end
      @last_master_out = @master_osc.process(eff_master_phase)

      # 4. Calculate slave phases (Hard Sync)
      base_slave_phase1 = @master_phase * @sync_ratio
      base_slave_phase2 = base_slave_phase1 + @duty

      # 5. Apply FM to slaves
      fm_mod = @fm_index * @last_fm_mod_out
      linear_fm_factor = 1.0 + fm_mod * @fm_linear_amt
      pm_offset = fm_mod * (1.0 - @fm_linear_amt) * 0.5

      slave_phase1 = base_slave_phase1 * linear_fm_factor + pm_offset
      slave_phase2 = base_slave_phase2 * linear_fm_factor + pm_offset

      slave_phase1 -= slave_phase1.floor
      slave_phase2 -= slave_phase2.floor

      # 6. Generate slave outputs
      @last_slave_out1 = @slave_osc1.process(slave_phase1)
      @last_slave_out2 = @slave_osc2.process(slave_phase2)

      # 7. Apply Kaiser windows (COLA)
      w1 = @window[slave_phase1]
      w2 = @window[slave_phase2]

      output = 0.5 * (@last_slave_out1 * w1 + @last_slave_out2 * w2)

      # 8. Advance master phase (with inharmonicity from master oscillator)
      @master_phase += @master_inc * @master_osc.freq_mult
      @master_phase -= 1.0 if @master_phase >= 1.0

      output
    end

    private

    def update_fm_inc
      @fm_mod_inc = @freq * @fm_ratio * inv_srate
    end

    def update_beta
      @master_osc.beta = @beta
      @slave_osc1.beta = @beta
      @slave_osc2.beta = @beta
    end

    def update_morph
      @master_osc.morph = @morph
      @slave_osc1.morph = @morph
      @slave_osc2.morph = @morph
    end

    def update_inharmonicity
      @master_osc.inharmonicity = @inharmonicity
      @slave_osc1.inharmonicity = @inharmonicity
      @slave_osc2.inharmonicity = @inharmonicity
    end

    def generate_window
      @window = LookupTable.new(:bits => 10) do |phase|
        # Kaiser-Bessel window generation logic
        # For simplicity and performance, if alpha is very small, we use a triangular window
        if @window_alpha < 0.001
          phase < 0.5 ? 2.0 * phase : 2.0 * (1.0 - phase)
        else
          # Full Kaiser-Bessel window lookup would be better pre-computed
          # But since window_alpha can change, we might need to regenerate or use more alphas
          calc_kaiser_value(phase, @window_alpha)
        end
      end
    end

    def get_window_value(phase)
      @window[phase]
    end

    def calc_kaiser_value(phase, alpha)
      # Normalized phase from 0 to 1
      # Convert to -1 to 1 for the Kaiser formula
      x = 4.0 * phase - 1.0
      # We actually want the Kaiser-Bessel derived window which is slightly different
      # than a standard Kaiser window. The C++ code integrates Bessel I0.
      # For now, let's use a standard Kaiser window centered at 0.5
      return 0.0 if x.abs > 1.0 # Should not happen with phase 0-1 and x = 4p-1? 
      # Actually x = 2*phase - 1 would be for phase 0-1.
      # The C++ code does: double x = 4.0 * i / WINDOW_SIZE - 1.0;
      # and mirrors it.
      
      # Let's re-implement the C++ logic for window generation more accurately if possible.
      # But doing it inside LookupTable constructor is fine.
      # Wait, the C++ code does an integration (cumulative sum).
      @kaiser_table ||= generate_kaiser_table(alpha)
    end

    def generate_kaiser_table(alpha)
      # Re-implementing the C++ generateKaiserWindow logic
      table = Array.new(WINDOW_SIZE)
      sum_val = 0.0
      half_len = WINDOW_SIZE / 2

      (0...half_len).each do |i|
        x = 4.0 * i / WINDOW_SIZE - 1.0
        arg = PI * alpha * ::Math.sqrt([0.0, 1.0 - x * x].max)
        sum_val += bessel_i0(arg)
        table[i] = sum_val
      end

      # Add final value for normalization
      x = 4.0 * half_len / WINDOW_SIZE - 1.0
      arg = PI * alpha * ::Math.sqrt([0.0, 1.0 - x * x].max)
      norm = sum_val + bessel_i0(arg)

      (0...half_len).each do |i|
        table[i] /= norm
        table[WINDOW_SIZE - 1 - i] = table[i]
      end
      
      table
    end

    # Override generate_window to use the more accurate table
    def generate_window
      @kaiser_table = generate_kaiser_table(@window_alpha)
      @window = LookupTable.new(:bits => 10) do |phase|
        idx = (phase * (WINDOW_SIZE - 1)).round
        @kaiser_table[idx] || 0.0
      end
    end

    NUM_COEFFS = [
      0.144048298227235e10,
      0.356644482244025e9,
      0.216415572361227e8,
      0.571661130563785e6,
      0.830792541809429e4,
      0.754337328948189e2,
      0.463076284721000e0,
      0.202591084143397e-2,
      0.654858370096785e-5,
      0.160224679395361e-7,
      0.300931127112960e-10,
      0.435125971262668e-13,
      0.479440257548300e-16,
      0.380715242345326e-19,
      0.210580722890567e-22
    ].reverse

    def bessel_i0(x)
      return 1.0 if x == 0.0
      z = x * x
      
      numerator = 0.0
      NUM_COEFFS.each do |c|
        numerator = numerator * z + c
      end
      numerator *= z

      denominator = z * (z * (z - 0.307646912682801e4) +
                         0.347626332405882e7) - 0.144048298227235e10

      -numerator / denominator
    end

  end

end
