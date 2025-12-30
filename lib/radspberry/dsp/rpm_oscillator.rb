module DSP

  # RPM (Recursive Phase Modulation) Oscillator
  # A single oscillator that can produce saw-like or square-like waveforms
  # via self-modulating phase feedback.
  #
  # Modes:
  #   :saw    - Linear feedback (y), RMS-normalized -> all harmonics
  #   :square - Squared feedback (y²), power-normalized -> odd harmonics
  #
  class RPMOscillator < Oscillator
    include DSP::Math

    param_accessor :beta,          :default => 1.5,   :range => (0.0..5.0)
    param_accessor :mode,          :default => :saw   # :saw or :square
    param_accessor :inharmonicity, :default => 0.0,   :range => (-0.5..0.5)

    POWER_ALPHA = 0.001   # Power tracking time constant
    CURV_ALPHA  = 0.001   # Curvature RMS tracking time constant

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.5
      @mode = :saw
      @inharmonicity = 0.0
      super freq
      clear!
    end

    def clear!
      @phase = 0.0
      @last_out = 0.0
      @last_out_prev = 0.0
      @last_out_prev2 = 0.0
      @rms_sq = 0.5
      @curv_rms = 0.01
    end

    def tick
      # k: curvature-based frequency modulation
      # tanh soft-limits normalized curvature to preserve spectral slope
      curv = @last_out - 2.0 * @last_out_prev + @last_out_prev2
      @curv_rms += CURV_ALPHA * (curv * curv - @curv_rms)
      curv_norm = curv / ::Math.sqrt([@curv_rms, 1e-6].max)
      freq_mult = 1.0 + inharmonicity * ::Math.tanh(curv_norm).abs

      # Advance phase with k
      @phase += @freq * inv_srate * freq_mult
      @phase -= 1.0 if @phase >= 1.0

      # Compute output based on mode
      y = case @mode
          when :saw
            compute_saw
          when :square
            compute_square
          else
            compute_saw  # default
          end

      # Update history
      @last_out_prev2 = @last_out_prev
      @last_out_prev = @last_out
      @last_out = y
      y
    end

    private

    def compute_saw
      # TPT: 2-point average for linear feedback
      y_avg = 0.5 * (@last_out + @last_out_prev)

      # Track power using single sample
      y_sq = @last_out * @last_out
      @rms_sq += POWER_ALPHA * (y_sq - @rms_sq)
      rms = ::Math.sqrt([@rms_sq, 0.01].max)

      # RMS-normalized feedback, scaled by 0.5, negated
      u = -@beta * 0.5 * (y_avg / rms)
      sin(DSP::TWO_PI * @phase + u)
    end

    def compute_square
      # TPT: 2-point average for squared feedback
      ysq_avg = 0.5 * (@last_out * @last_out + @last_out_prev * @last_out_prev)

      # Track power using ysq_avg
      @rms_sq += POWER_ALPHA * (ysq_avg - @rms_sq)

      # Power-normalized feedback, centered around 0, negated
      u = -@beta * (ysq_avg / [@rms_sq, 0.01].max * 0.5 - 0.5)
      sin(DSP::TWO_PI * @phase + u)
    end
  end

end
