# Biquad filter - interpolating Direct-form 1

module DSP
  class Biquad < Processor
    include Math

    def initialize(num = [1.0, 0, 0], den = [1.0, 0, 0], opts = {})
      super()
      @interpolate = opts[:interpolate]
      @denorm = ANTI_DENORMAL
      update_arrays(num, den)
      normalize if @coeffs[1][0] != 1.0
      clear!
    end

    def update_arrays(b, a)
      @coeffs = [b.to_a, a.to_a]
    end

    def b
      @coeffs[0]
    end

    def a
      @coeffs[1]
    end

    def normalize
      a0 = @coeffs[1][0]
      return if a0 == 1.0
      inv = 1.0 / a0
      new_b = @coeffs[0].map { |x| x * inv }
      new_a = @coeffs[1].map { |x| x * inv }
      @coeffs = [new_b, new_a]
    end

    def clear!
      @input = [0.0, 0.0, 0.0]
      @output = [0.0, 0.0, 0.0]
      stop_interpolation
    end

    def process(input, b_arg = nil, a_arg = nil)
      if b_arg
        b, a = b_arg, a_arg
      else
        # Atomic read of coefficients
        b, a = @coeffs
      end
      
      output = b[0] * input + b[1] * @input[1] + b[2] * @input[2]
      output -= a[1] * @output[1] + a[2] * @output[2]
      @input[2] = @input[1]
      @input[1] = input + ANTI_DENORMAL
      @output[2] = @output[1]
      @output[1] = output
      output
    end

    def update(b, a)
      new_b, new_a = b.to_a, a.to_a
      
      if @interpolate && @coeffs
        # If already interpolating, continue from current interp state
        # If not, start from current static coeffs
        start_b = @_b || @coeffs[0]
        start_a = @_a || @coeffs[1]
        
        @_b, @_a = start_b.dup, start_a.dup
      end
      
      @coeffs = [new_b, new_a]
      
      if @interpolate && @_b && @_a
        interpolate(new_b, new_a)
      end
    end

    def interpolate(target_b, target_a)
      @interp_period = (srate * 1e-3).floor
      t = 1.0 / @interp_period
      
      # Vector math for deltas (target - current)
      # Using arrays manually to avoid Vector allocations
      @delta_b = [0,1,2].map { |i| (target_b[i] - @_b[i]) * t }
      @delta_a = [0,1,2].map { |i| (target_a[i] - @_a[i]) * t }
      
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
        3.times do |i|
          @_b[i] += @delta_b[i]
          @_a[i] += @delta_a[i]
        end
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
