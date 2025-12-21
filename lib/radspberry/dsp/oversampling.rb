module DSP

  # 12th order elliptic lowpass filter for 4x oversampling
  # Cutoff at 1/4 Nyquist (quarter-band), very steep rolloff
  # Ported from rosic_EllipticQuarterBandFilter
  class EllipticQuarterBandFilter < Processor
    TINY = 1e-20

    # Pre-computed coefficients for elliptic lowpass at fs/4
    A = [
      -9.1891604652189471,
      40.177553696870497,
      -110.11636661771178,
      210.18506612078195,
      -293.84744771903240,
      308.16345558359234,
      -244.06786780384243,
      144.81877911392738,
      -62.770692151724198,
      18.867762095902137,
      -3.5327094230551848,
      0.31183189275203149
    ].freeze

    B = [
      0.00013671732099945628,
      -0.00055538501265606384,
      0.0013681887636296387,
      -0.0022158566490711852,
      0.0028320091007278322,
      -0.0029776933151090413,
      0.0030283628243514991,
      -0.0029776933151090413,
      0.0028320091007278331,
      -0.0022158566490711861,
      0.0013681887636296393,
      -0.00055538501265606384,
      0.00013671732099945636
    ].freeze

    def initialize
      clear!
    end

    def clear!
      @w = Array.new(12, 0.0)
    end

    def tick(input)
      # Direct Form II implementation
      tmp = input + TINY
      tmp -= A[0]*@w[0] + A[1]*@w[1] + A[2]*@w[2] + A[3]*@w[3]
      tmp -= A[4]*@w[4] + A[5]*@w[5] + A[6]*@w[6] + A[7]*@w[7]
      tmp -= A[8]*@w[8] + A[9]*@w[9] + A[10]*@w[10] + A[11]*@w[11]

      y = B[0]*tmp
      y += B[1]*@w[0] + B[2]*@w[1] + B[3]*@w[2] + B[4]*@w[3]
      y += B[5]*@w[4] + B[6]*@w[5] + B[7]*@w[6] + B[8]*@w[7]
      y += B[9]*@w[8] + B[10]*@w[9] + B[11]*@w[10] + B[12]*@w[11]

      # Shift state
      11.downto(1) { |i| @w[i] = @w[i-1] }
      @w[0] = tmp

      y
    end
  end

  # Simple 2-pole Butterworth lowpass for 2x oversampling
  # Cutoff at 1/2 Nyquist (half-band)
  class HalfBandFilter < Processor
    def initialize
      # Butterworth coefficients for fc = 0.25 * fs (half Nyquist)
      # These are pre-computed for the fixed cutoff ratio
      @b0 = 0.2928932188134524
      @b1 = 0.5857864376269049
      @b2 = 0.2928932188134524
      @a1 = 0.0
      @a2 = 0.17157287525380993
      clear!
    end

    def clear!
      @x1 = @x2 = 0.0
      @y1 = @y2 = 0.0
    end

    def tick(input)
      y = @b0 * input + @b1 * @x1 + @b2 * @x2 - @a1 * @y1 - @a2 * @y2
      @x2, @x1 = @x1, input
      @y2, @y1 = @y1, y
      y
    end
  end

  # Steeper halfband using cascaded biquads (4th order)
  class SteepHalfBandFilter < Processor
    def initialize
      @stage1 = HalfBandFilter.new
      @stage2 = HalfBandFilter.new
    end

    def clear!
      @stage1.clear!
      @stage2.clear!
    end

    def tick(input)
      @stage2.tick(@stage1.tick(input))
    end
  end

  # Oversampler wrapper - processes at higher internal sample rate
  #
  # Uses 4x oversampling with elliptic quarter-band anti-aliasing filter.
  # The quarter-band filter has cutoff at 1/8 of the 4x rate = original Nyquist.
  #
  # Usage:
  #   oversampled_filter = DSP.oversample(MyFilter.new)
  #   output = oversampled_filter.tick(input)
  class Oversampler < Processor
    FACTOR = 4

    def initialize(processor)
      @processor = processor
      @upsample_filter = EllipticQuarterBandFilter.new
      @downsample_filter = EllipticQuarterBandFilter.new
    end

    def factor
      FACTOR
    end

    def clear!
      @processor.clear! if @processor.respond_to?(:clear!)
      @upsample_filter.clear!
      @downsample_filter.clear!
    end

    def tick(input)
      # Upsample 4x: zero-stuff with gain compensation
      # Only first sample has signal, rest are zeros
      up0 = @upsample_filter.tick(input * FACTOR)
      up1 = @upsample_filter.tick(0.0)
      up2 = @upsample_filter.tick(0.0)
      up3 = @upsample_filter.tick(0.0)

      # Process 4 samples at 4x rate
      out0 = @processor.tick(up0)
      out1 = @processor.tick(up1)
      out2 = @processor.tick(up2)
      out3 = @processor.tick(up3)

      # Downsample: filter all, return last (decimation by 4)
      @downsample_filter.tick(out0)
      @downsample_filter.tick(out1)
      @downsample_filter.tick(out2)
      @downsample_filter.tick(out3)
    end

    # Forward method calls to wrapped processor
    def method_missing(method, *args, &block)
      if @processor.respond_to?(method)
        @processor.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @processor.respond_to?(method, include_private) || super
    end
  end

  # Convenience method to create oversampled processor
  def self.oversample(processor)
    Oversampler.new(processor)
  end

  # Wraps a complete signal chain (Generator >> Processors) with 4x oversampling
  # The entire chain runs at 4x sample rate, with decimation at output
  #
  # Usage:
  #   chain = OversampledChain.new do
  #     osc = Phasor.new(440)
  #     filter = AudioRateSVF.new(freq: 2000, drive: 12.0)
  #     osc >> filter
  #   end
  #   output = chain.tick
  #
  class OversampledChain < Generator
    FACTOR = 4

    def initialize(&block)
      # Temporarily set sample rate to 4x for building the chain
      @original_srate = Base.srate
      @oversampled_srate = @original_srate * FACTOR

      # Build chain at oversampled rate
      Base.sample_rate = @oversampled_srate
      @chain = block.call
      Base.sample_rate = @original_srate

      @downsample_filter = EllipticQuarterBandFilter.new
    end

    def factor
      FACTOR
    end

    def tick
      # Generate 4 samples at oversampled rate
      out0 = @chain.tick
      out1 = @chain.tick
      out2 = @chain.tick
      out3 = @chain.tick

      # Decimate with anti-aliasing filter
      @downsample_filter.tick(out0)
      @downsample_filter.tick(out1)
      @downsample_filter.tick(out2)
      @downsample_filter.tick(out3)
    end

    def clear!
      @chain.clear! if @chain.respond_to?(:clear!)
      @downsample_filter.clear!
    end

    # Forward to chain for parameter access
    def method_missing(method, *args, &block)
      if @chain.respond_to?(method)
        @chain.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @chain.respond_to?(method, include_private) || super
    end
  end

  # Convenience for creating oversampled chains
  def self.oversampled(&block)
    OversampledChain.new(&block)
  end

end
