# Exponential ramp generator - Thread safe
module DSP
  class ExponentialLine < Generator
    attr_accessor :start_val, :finish_val, :duration

    def initialize(start_val = 0.001, finish_val = 1.0, duration = 1.0)
      @start_val = start_val == 0 ? 1e-6 : start_val
      @finish_val = finish_val == 0 ? 1e-6 : finish_val
      @duration = duration
      reset!
    end

    def trigger!
      reset!
    end

    def reset!
      @current_sample = 0
      @total_samples = (@duration * srate).to_i
      @ratio = @finish_val.to_f / @start_val.to_f
    end

    def tick
      if @current_sample < @total_samples
        t = @current_sample.to_f / @total_samples
        val = @start_val * (@ratio ** t)
        @current_sample += 1
        val
      else
        @finish_val
      end
    end

    def srate=(rate)
      super
      reset!
    end
  end
end
