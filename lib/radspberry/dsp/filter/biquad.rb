# Biquad filter - interpolating Direct-form 1

module DSP
  class Biquad < Processor
    include Math

    def initialize(num = [1.0, 0, 0], den = [1.0, 0, 0], opts = {})
      @interpolate = opts[:interpolate]
      @denorm = ANTI_DENORMAL
      update(Vector[*num], Vector[*den])
      normalize if @a[0] != 1.0
      clear!
    end

    def normalize
      inv = 1.0 / @a[0]
      @b *= inv
      @a *= inv
    end

    def clear!
      @input = [0, 0, 0]
      @output = [0, 0, 0]
      stop_interpolation
    end

    def process(input, b = @b, a = @a)
      output = b[0] * input + b[1] * @input[1] + b[2] * @input[2]
      output -= a[1] * @output[1] + a[2] * @output[2]
      @input[2] = @input[1]
      @input[1] = input + ANTI_DENORMAL
      @output[2] = @output[1]
      @output[1] = output
    end

    def update(b, a)
      if @interpolate && @b && @a
        @_b, @_a = @b, @a
      end
      @b, @a = b, a
      if @interpolate && @_b && @_a
        interpolate
      end
    end

    def interpolate
      @interp_period = (srate * 1e-3).floor
      t = 1.0 / @interp_period
      @delta_b = (@b - @_b) * t
      @delta_a = (@a - @_a) * t
      @interp_ticks = 0
    end

    def interpolating?
      @_b && @_a
    end

    def stop_interpolation
      @_b = @_a = nil
    end

    def tick(input)
      if interpolating?
        @_b += @delta_b
        @_a += @delta_a
        process(input, @_b, @_a).tap do
          stop_interpolation if (@interp_ticks += 1) >= @interp_period
        end
      else
        process(input)
      end
    end

    attr_reader :freq

    def freq=(arg)
      @freq = DSP.to_freq(arg)
      @w0 = TWO_PI * @freq * inv_srate
      recalc
    end
  end
end
