# Linear ramp generator - Thread safe (no Fibers)
module DSP
  class Line < Generator
    attr_accessor :start_val, :finish_val, :duration

    def initialize(start_val = 0.0, finish_val = 1.0, duration = 1.0)
      @start_val = start_val
      @finish_val = finish_val
      @duration = duration
      reset!
    end

    def trigger!
      reset!
    end

    def reset!
      @current_sample = 0
      @total_samples = (@duration * srate).to_i
    end

    def tick
      if @current_sample < @total_samples
        t = @current_sample.to_f / @total_samples
        val = @start_val + (@finish_val - @start_val) * t
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
