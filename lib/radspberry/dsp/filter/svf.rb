# State Variable Filter (SVF)
# Based on Cytomic/Zavalishin TPT topology

module DSP
  class SVF < Processor
    include Math
    attr_accessor :kind, :freq

    def initialize(kind: :low)
      @kind = kind
      @q = 0.707
      @freq = 1000.0
      clear!
    end

    def clear!
      @v0z = 0
      @v1 = 0
      @v2 = 0
      @output = {}
    end

    def freq=(f)
      @freq = DSP.to_freq(f.to_f)
      recalc
    end

    def q=(q)
      @q = q
      recalc
    end

    def recalc
      @g = tan(PI * @freq * inv_srate)
      @k = 1.0 / @q
      @ginv = @g / (1.0 + @g * (@g + @k))
      @g1 = @ginv
      @g2 = 2.0 * (@g + @k) * @ginv
      @g3 = @g * @ginv
      @g4 = 2.0 * @ginv
    end

    def process(input)
      @v0 = input
      @v1z = @v1
      @v2z = @v2
      @v3 = @v0 + @v0z - 2.0 * @v2z
      @v1 += @g1 * @v3 - @g2 * @v1z
      @v2 += @g3 * @v3 + @g4 * @v1z
      @v0z = @v0
      @output[:lp] = @v2
      @output[:bp] = @v1
      @output[:hp] = @v0 - @k * @v1 - @v2
      @output[:notch] = @v0 - @k * @v1
    end

    def tick(input)
      process(input)
      @output[@kind]
    end
  end


  class AudioRateSVF < Processor
    include Math

    attr_reader :freq, :q, :g, :drive
    attr_accessor :kind

    def initialize(freq: 1000.0, q: 0.707, kind: :low, drive: 0.0)
      @kind = kind
      @drive = drive
      @drive_gain = 10.0 ** (drive / 20.0)
      @q = q
      @freq = freq
      clear!
      recalc
    end

    def clear!
      @z1 = 0.0
      @z2 = 0.0
      @z1_2 = 0.0
      @z2_2 = 0.0
      @four_pole = false
    end

    def four_pole=(enabled)
      @four_pole = enabled
    end

    def four_pole?
      @four_pole
    end

    def freq=(f, update: true)
      @freq = DSP.to_freq(f.to_f).clamp(20.0, srate * 0.49)
      recalc if update
    end

    def q=(value, update: true)
      @q = value.clamp(0.5, 50.0)
      recalc if update
    end

    def drive=(db)
      @drive = db
      @drive_gain = 10.0 ** (db / 20.0)
    end

    def g=(value)
      @g = value
      update_coefficients
    end

    def freq_to_g(f)
      DSP.fast_tan(f * inv_srate)
    end

    def set_freq_fast(f)
      @freq = f
      @g = freq_to_g(f)
      update_coefficients
    end

    def recalc
      @g = tan(PI * @freq * inv_srate)
      update_coefficients
    end

    def update_coefficients
      effective_q = @four_pole ? @q * 0.8 : @q
      @k = 1.0 / effective_q
      denom = 1.0 + @g * (@g + @k)
      @a1 = 1.0 / denom
      @a2 = @g * @a1
      @a3 = @g * @a2
    end

    def saturate(x)
      return x if @drive <= 0.0
      DSP.fast_tanh(x * @drive_gain) / @drive_gain
    end

    def tick(input)
      x = @drive > 0 ? saturate(input * @drive_gain) : input

      hp = (x - @k * @z1 - @z2) * @a1
      bp = @a2 * hp + @z1
      lp = @a3 * hp + @a2 * @z1 + @z2

      @z1 = 2.0 * bp - @z1
      @z2 = 2.0 * lp - @z2

      if @z1.abs > 20.0
        @z1 = DSP.fast_tanh(@z1 * 0.015625) * 64.0
      end
      if @z2.abs > 20.0
        @z2 = DSP.fast_tanh(@z2 * 0.015625) * 64.0
      end

      if @four_pole
        x2 = @drive > 0 ? saturate(lp) : lp

        hp2 = (x2 - @k * @z1_2 - @z2_2) * @a1
        bp2 = @a2 * hp2 + @z1_2
        lp2 = @a3 * hp2 + @a2 * @z1_2 + @z2_2

        @z1_2 = 2.0 * bp2 - @z1_2
        @z2_2 = 2.0 * lp2 - @z2_2

        if @z1_2.abs > 20.0
          @z1_2 = DSP.fast_tanh(@z1_2 * 0.015625) * 64.0
        end
        if @z2_2.abs > 20.0
          @z2_2 = DSP.fast_tanh(@z2_2 * 0.015625) * 64.0
        end

        lp, bp, hp = lp2, bp2, x - lp2 - @k * bp2
      end

      case @kind
      when :low then lp
      when :band then bp
      when :high then hp
      when :notch then lp + hp
      when :all then { low: lp, band: bp, high: hp, notch: lp + hp }
      else lp
      end
    end

    def tick_with_mod(input, mod_freq)
      set_freq_fast(mod_freq)
      tick(input)
    end
  end


  class BellSVF < SVF
    def recalc
      @gb = 10.0 ** (dbGain * 0.025)
      @g = tan(PI * @freq * inv_srate)
      @k = 1.0 / (@q * @gb)
      @gi = @k * (@gb * @gb - 1)
      @ginv = @g / (1.0 + @g * (@g + @k))
      @g1 = @ginv
      @g2 = 2.0 * (@g + @k) * @ginv
      @g3 = @g * @ginv
      @g4 = 2.0 * @ginv
    end

    def tick(input)
      @v0 = @gi * input
      @v1z = @v1
      @v2z = @v2
      @v3 = @v0 + @v0z - 2.0 * @v2z
      @v1 += @g1 * @v3 - @g2 * @v1z
      @v2 += @g3 * @v3 + @g4 * @v1z
      @v0z = @v0
      @output = input + @v1
    end
  end
end
