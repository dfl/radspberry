# Linear ramp generator
module DSP
  class Line < FiberGenerator
    attr_accessor :start_val, :finish_val, :duration

    def initialize(start_val = 0.0, finish_val = 1.0, duration = 1.0)
      @start_val = start_val
      @finish_val = finish_val
      @duration = duration
      super()
    end

    def trigger!
      reset!
    end

    protected

    def create_fiber
      Fiber.new do
        samples = (@duration * srate).to_i
        
        if samples <= 0
          Fiber.yield(@finish_val)
        else
          samples.times do |i|
            t = i.to_f / samples
            Fiber.yield(@start_val + ( @finish_val - @start_val ) * t )
          end
        end

        loop { Fiber.yield(@finish_val) }
      end
    end
  end
end
