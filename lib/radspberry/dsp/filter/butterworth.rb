# Butterworth filter family

module DSP
  class Butterworth < Biquad
    attr_reader :resonance
    MAX_Q = 25.0

    def initialize(f = 100, q: nil)
      super([1.0, 0, 0], [1.0, 0, 0], interpolate: true)
      @inv_q = q ? 1.0 / q : SQRT2
      self.freq = f
    end

    def resonance= r  # 0 - 1
      @resonance = r
      # Map 0..1 to SQRT2_2..MAX_Q exponentially
      target_q = SQRT2_2 * (MAX_Q / SQRT2_2) ** @resonance
      self.q = target_q
    end

    def q
      1.0 / @inv_q
    end

    def q=(arg)
      @inv_q = 1.0 / arg
      recalc
    end
  end


  class ButterHP < Butterworth
    def recalc
      temp = 0.5 * @inv_q * sin(@w0)
      beta = 0.5 * (1.0 - temp) / (1.0 + temp)
      gamma = (0.5 + beta) * cos(@w0)
      alpha = (0.5 + beta + gamma) * 0.25

      b0 = 2.0 * alpha
      b1 = 2.0 * -2.0 * alpha
      b2 = 2.0 * alpha
      a0 = 1.0
      a1 = 2.0 * -gamma
      a2 = 2.0 * beta

      update([b0, b1, b2], [a0, a1, a2])
      normalize if a[0] != 1.0
    end
  end


  class ButterLP < Butterworth
    def recalc
      k = tan(PI * @freq * inv_srate)
      norm = 1.0 / (1.0 + k * @inv_q + k * k)

      b0 = k * k * norm
      b1 = 2.0 * b0
      b2 = b0
      a0 = 1.0
      a1 = 2.0 * (k * k - 1.0) * norm
      a2 = (1.0 - k * @inv_q + k * k) * norm

      update([b0, b1, b2], [a0, a1, a2])
    end
  end


  class ButterBP < Butterworth
    def recalc
      k = tan(PI * @freq * inv_srate)
      norm = 1.0 / (1.0 + k * @inv_q + k * k)

      # Bandpass at unity gain: b0 = k * inv_q * norm
      b0 = k * @inv_q * norm
      b1 = 0.0
      b2 = -b0
      a0 = 1.0
      a1 = 2.0 * (k * k - 1.0) * norm
      a2 = (1.0 - k * @inv_q + k * k) * norm

      update([b0, b1, b2], [a0, a1, a2])
    end
  end


  class ButterNotch < Butterworth
    def recalc
      k = tan(PI * @freq * inv_srate)
      norm = 1.0 / (1.0 + k * @inv_q + k * k)

      # Notch at unity gain: b0 = (1 + k^2) * norm
      # Frequency response at freq is (1 - k^2)/(1 - k^2) = 1.0? 
      # Actually for Notch, standard is b0=1, b1=a1, b2=1, norm...
      b0 = (1.0 + k * k) * norm
      b1 = 2.0 * (k * k - 1.0) * norm
      b2 = b0
      a0 = 1.0
      a1 = b1
      a2 = (1.0 - k * @inv_q + k * k) * norm

      update([b0, b1, b2], [a0, a1, a2])
    end
  end


end
