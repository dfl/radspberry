# Butterworth filter family

module DSP
  class ButterHP < Biquad
    def initialize(f = 100, q: nil)
      super([1.0, 0, 0], [1.0, 0, 0], interpolate: true)
      @inv_q = q ? 1.0 / q : SQRT2
      self.freq = f
    end

    def q
      1.0 / @inv_q
    end

    def q=(arg)
      @inv_q = 1.0 / arg
      recalc
    end

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

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
      normalize if @a[0] != 1.0
    end
  end


  class ButterLP < ButterHP
    def recalc
      k = tan(PI * @freq * inv_srate)
      norm = 1.0 / (1.0 + k * @inv_q + k * k)

      b0 = k * k * norm
      b1 = 2.0 * b0
      b2 = b0
      a0 = 1.0
      a1 = 2.0 * (k * k - 1.0) * norm
      a2 = (1.0 - k * @inv_q + k * k) * norm

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end


  class ButterBP < ButterHP
    def recalc
      k = tan(PI * @freq * inv_srate)
      norm = 1.0 / (1.0 + k * @inv_q + k * k)

      b0 = k * norm
      b1 = 0.0
      b2 = -b0
      a0 = 1.0
      a1 = 2.0 * (k * k - 1.0) * norm
      a2 = (1.0 - k * @inv_q + k * k) * norm

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end


  class ButterNotch < ButterHP
    def recalc
      k = tan(PI * @freq * inv_srate)
      norm = 1.0 / (1.0 + k * @inv_q + k * k)

      b0 = (1.0 + k * k) * norm
      b1 = 2.0 * (k * k - 1.0) * norm
      b2 = b0
      a0 = 1.0
      a1 = b1
      a2 = (1.0 - k * @inv_q + k * k) * norm

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end


  class ButterPeak < ButterHP
    param_accessor :gain, :default => 0.0, :after_set => Proc.new { recalc }

    def initialize(f = 1000, q: nil, gain: 0.0)
      @gain = gain
      super(f, q: q)
    end

    def recalc
      k = tan(PI * @freq * inv_srate)
      v = 10.0 ** (@gain.abs / 20.0)

      if @gain >= 0.0
        norm = 1.0 / (1.0 + @inv_q * k + k * k)
        b0 = (1.0 + v * @inv_q * k + k * k) * norm
        b1 = 2.0 * (k * k - 1.0) * norm
        b2 = (1.0 - v * @inv_q * k + k * k) * norm
        a0 = 1.0
        a1 = b1
        a2 = (1.0 - @inv_q * k + k * k) * norm
      else
        norm = 1.0 / (1.0 + v * @inv_q * k + k * k)
        b0 = (1.0 + @inv_q * k + k * k) * norm
        b1 = 2.0 * (k * k - 1.0) * norm
        b2 = (1.0 - @inv_q * k + k * k) * norm
        a0 = 1.0
        a1 = b1
        a2 = (1.0 - v * @inv_q * k + k * k) * norm
      end

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end


  class ButterLowShelf < ButterHP
    param_accessor :gain, :default => 0.0, :after_set => Proc.new { recalc }

    def initialize(f = 1000, q: nil, gain: 0.0)
      @gain = gain
      super(f, q: q)
    end

    def recalc
      k = tan(PI * @freq * inv_srate)
      v = 10.0 ** (@gain.abs / 20.0)

      if @gain >= 0.0
        norm = 1.0 / (1.0 + SQRT2 * k + k * k)
        b0 = (1.0 + ::Math.sqrt(2.0 * v) * k + v * k * k) * norm
        b1 = 2.0 * (v * k * k - 1.0) * norm
        b2 = (1.0 - ::Math.sqrt(2.0 * v) * k + v * k * k) * norm
        a0 = 1.0
        a1 = 2.0 * (k * k - 1.0) * norm
        a2 = (1.0 - SQRT2 * k + k * k) * norm
      else
        norm = 1.0 / (1.0 + ::Math.sqrt(2.0 * v) * k + v * k * k)
        b0 = (1.0 + SQRT2 * k + k * k) * norm
        b1 = 2.0 * (k * k - 1.0) * norm
        b2 = (1.0 - SQRT2 * k + k * k) * norm
        a0 = 1.0
        a1 = 2.0 * (v * k * k - 1.0) * norm
        a2 = (1.0 - ::Math.sqrt(2.0 * v) * k + v * k * k) * norm
      end

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end


  class ButterHighShelf < ButterHP
    param_accessor :gain, :default => 0.0, :after_set => Proc.new { recalc }

    def initialize(f = 1000, q: nil, gain: 0.0)
      @gain = gain
      super(f, q: q)
    end

    def recalc
      k = tan(PI * @freq * inv_srate)
      v = 10.0 ** (@gain.abs / 20.0)

      if @gain >= 0.0
        norm = 1.0 / (1.0 + SQRT2 * k + k * k)
        b0 = (v + ::Math.sqrt(2.0 * v) * k + k * k) * norm
        b1 = 2.0 * (k * k - v) * norm
        b2 = (v - ::Math.sqrt(2.0 * v) * k + k * k) * norm
        a0 = 1.0
        a1 = 2.0 * (k * k - 1.0) * norm
        a2 = (1.0 - SQRT2 * k + k * k) * norm
      else
        norm = 1.0 / (v + ::Math.sqrt(2.0 * v) * k + k * k)
        b0 = (1.0 + SQRT2 * k + k * k) * norm
        b1 = 2.0 * (k * k - 1.0) * norm
        b2 = (1.0 - SQRT2 * k + k * k) * norm
        a0 = 1.0
        a1 = 2.0 * (k * k - v) * norm
        a2 = (v - ::Math.sqrt(2.0 * v) * k + k * k) * norm
      end

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end
end
