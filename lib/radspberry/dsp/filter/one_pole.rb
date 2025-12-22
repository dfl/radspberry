# One-pole filters and zero-delay variants

module DSP
  class OnePoleZD < Processor
    attr_accessor :state, :freq
    include Math

    def initialize
      freq = srate / 2.0
    end

    def freq=(freq)
      @freq = freq.to_f
      @f = tan(PI * @freq * inv_srate)
      @finv = 1.0 / (1.0 + @f)
    end

    def clear!
      @state = 0.0
    end
  end


  class ZDLP < OnePoleZD
    def tick(input)
      output = (@state + @f * input) * @finv
      @state = @f * (input - output) + output
      output
    end
  end


  class ZDHP < OnePoleZD
    def tick(input)
      low = (@state + @f * input) * @finv
      high = input - low
      @state = low + @f * high
      high
    end
  end
end
