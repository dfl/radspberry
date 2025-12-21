# DC blocking filter

module DSP
  class DCBlocker < Processor
    def initialize(r: 0.995)
      @r = r
      @x_prev = 0.0
      @y_prev = 0.0
    end

    def tick(input)
      output = input - @x_prev + @r * @y_prev
      @x_prev = input
      @y_prev = output
      output
    end

    def clear!
      @x_prev = 0.0
      @y_prev = 0.0
    end
  end
end
