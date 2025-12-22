# Polyphase IIR Oversampling
#
# Ported from Laurent de Soras' HIIR library
# Copyright (c) Laurent de Soras
# Licensed under WTFPL - http://www.wtfpl.net/
# Reference: http://ldesoras.free.fr/prod.html#src_hiir
#
# Uses two-path allpass structure for efficient halfband filtering.
# The polyphase IIR approach is more efficient than traditional FIR
# halfband filters while providing excellent stopband attenuation.

module DSP

  # Polyphase IIR Halfband Filter for 2x oversampling
  class PolyphaseHalfband < Processor
    # Pre-computed coefficient sets for different quality levels
    COEFS = {
      # 156 dB stopband attenuation, 12 coefficients
      ultra: [
        0.017347915108876406,
        0.067150480426919179,
        0.14330738338179819,
        0.23745131944299824,
        0.34085550201503761,
        0.44601111310335906,
        0.54753112652956148,
        0.6423859124721446,
        0.72968928615804163,
        0.81029959388029904,
        0.88644514917318362,
        0.96150605146543733
      ].freeze,

      # 125 dB stopband attenuation, 10 coefficients
      high: [
        0.026280277370383145,
        0.099994562200117765,
        0.20785425737827937,
        0.33334081139102473,
        0.46167004060691091,
        0.58273462309510859,
        0.69172302956824328,
        0.78828933879250873,
        0.87532862123185262,
        0.9580617608216595
      ].freeze,

      # 94 dB stopband attenuation, 8 coefficients (default)
      medium: [
        0.044076093956155402,
        0.16209555156378622,
        0.32057678606990592,
        0.48526821501990786,
        0.63402005787429128,
        0.75902855561016014,
        0.86299283427175177,
        0.9547836337311687
      ].freeze,

      # 64 dB stopband attenuation, 6 coefficients (lightweight)
      low: [
        0.086928900551398763,
        0.29505822040137708,
        0.52489392936346835,
        0.7137336652558357,
        0.85080135560651127,
        0.95333447720743869
      ].freeze
    }.freeze

    attr_reader :quality, :nbr_coefs

    def initialize(quality: :medium)
      @quality = quality
      @coefs = COEFS.fetch(quality)
      @nbr_coefs = @coefs.size
      @filter = Array.new(@nbr_coefs + 2) { [0.0, 0.0] }
      set_coefs(@coefs)
      clear!
    end

    def clear!
      @filter.each { |stage| stage[1] = 0.0 }
    end

    # Low-pass halfband filter - single sample
    def tick(input)
      low, _ = process_split(input)
      low
    end

    # High-pass halfband filter - single sample
    def tick_hpf(input)
      _, high = process_split(input)
      high
    end

    # Split into low and high bands simultaneously
    def process_split(input)
      spl_0, spl_1 = process_2_paths(input)
      low  = (spl_0 + spl_1) * 0.5
      high = (spl_0 - spl_1) * 0.5
      [low, high]
    end

    private

    def set_coefs(coef_arr)
      coef_arr.each_with_index do |c, i|
        @filter[i + 2][0] = c
      end
    end

    def process_2_paths(input)
      spl_0 = input
      spl_1 = @prev || 0.0

      i = 0
      while i < @nbr_coefs
        cnt = i + 2

        tmp_0 = spl_0
        tmp_0 -= @filter[cnt][1]
        tmp_0 *= @filter[cnt][0]
        tmp_0 += @filter[cnt - 2][1]
        @filter[cnt - 2][1] = spl_0

        if i + 1 < @nbr_coefs
          tmp_1 = spl_1
          tmp_1 -= @filter[cnt + 1][1]
          tmp_1 *= @filter[cnt + 1][0]
          tmp_1 += @filter[cnt - 1][1]
          @filter[cnt - 1][1] = spl_1

          spl_0 = tmp_0
          spl_1 = tmp_1
          i += 2
        else
          @filter[cnt - 1][1] = spl_1
          @filter[cnt][1] = tmp_0
          spl_0 = tmp_0
          i += 1
        end
      end

      if @nbr_coefs.even?
        cnt = @nbr_coefs + 2
        @filter[cnt - 2][1] = spl_0
        @filter[cnt - 1][1] = spl_1
      end

      @prev = input
      [spl_0, spl_1]
    end
  end

  # 2x Upsampler using polyphase IIR halfband filter
  class Upsampler2x < Processor
    def initialize(quality: :medium)
      @coefs = PolyphaseHalfband::COEFS.fetch(quality)
      @nbr_coefs = @coefs.size
      @filter = Array.new(@nbr_coefs + 2) { [0.0, 0.0] }
      @coefs.each_with_index { |c, i| @filter[i + 2][0] = c }
      clear!
    end

    def clear!
      @filter.each { |stage| stage[1] = 0.0 }
    end

    # Upsample one sample to two samples
    # Returns [out_0, out_1]
    def tick(input)
      process_sample_pos(input, input)
    end

    private

    def process_sample_pos(spl_0, spl_1)
      i = 0
      while i < @nbr_coefs
        cnt = i + 2

        tmp_0 = spl_0
        tmp_0 -= @filter[cnt][1]
        tmp_0 *= @filter[cnt][0]
        tmp_0 += @filter[cnt - 2][1]
        @filter[cnt - 2][1] = spl_0

        if i + 1 < @nbr_coefs
          tmp_1 = spl_1
          tmp_1 -= @filter[cnt + 1][1]
          tmp_1 *= @filter[cnt + 1][0]
          tmp_1 += @filter[cnt - 1][1]
          @filter[cnt - 1][1] = spl_1

          spl_0 = tmp_0
          spl_1 = tmp_1
          i += 2
        else
          @filter[cnt - 1][1] = spl_1
          @filter[cnt][1] = tmp_0
          spl_0 = tmp_0
          i += 1
        end
      end

      if @nbr_coefs.even?
        cnt = @nbr_coefs + 2
        @filter[cnt - 2][1] = spl_0
        @filter[cnt - 1][1] = spl_1
      end

      [spl_0, spl_1]
    end
  end

  # 2x Downsampler using polyphase IIR halfband filter
  class Downsampler2x < Processor
    def initialize(quality: :medium)
      @coefs = PolyphaseHalfband::COEFS.fetch(quality)
      @nbr_coefs = @coefs.size
      @filter = Array.new(@nbr_coefs + 2) { [0.0, 0.0] }
      @coefs.each_with_index { |c, i| @filter[i + 2][0] = c }
      clear!
    end

    def clear!
      @filter.each { |stage| stage[1] = 0.0 }
    end

    # Downsample two samples to one
    def tick(in_0, in_1 = nil)
      if in_0.is_a?(Array)
        in_1 = in_0[1]
        in_0 = in_0[0]
      end

      spl_0, spl_1 = process_sample_pos(in_1, in_0)
      (spl_0 + spl_1) * 0.5
    end

    # Returns both low and high bands
    def tick_split(in_0, in_1 = nil)
      if in_0.is_a?(Array)
        in_1 = in_0[1]
        in_0 = in_0[0]
      end

      spl_0, spl_1 = process_sample_pos(in_1, in_0)
      low = (spl_0 + spl_1) * 0.5
      high = spl_0 - low
      [low, high]
    end

    private

    def process_sample_pos(spl_0, spl_1)
      i = 0
      while i < @nbr_coefs
        cnt = i + 2

        tmp_0 = spl_0
        tmp_0 -= @filter[cnt][1]
        tmp_0 *= @filter[cnt][0]
        tmp_0 += @filter[cnt - 2][1]
        @filter[cnt - 2][1] = spl_0

        if i + 1 < @nbr_coefs
          tmp_1 = spl_1
          tmp_1 -= @filter[cnt + 1][1]
          tmp_1 *= @filter[cnt + 1][0]
          tmp_1 += @filter[cnt - 1][1]
          @filter[cnt - 1][1] = spl_1

          spl_0 = tmp_0
          spl_1 = tmp_1
          i += 2
        else
          @filter[cnt - 1][1] = spl_1
          @filter[cnt][1] = tmp_0
          spl_0 = tmp_0
          i += 1
        end
      end

      if @nbr_coefs.even?
        cnt = @nbr_coefs + 2
        @filter[cnt - 2][1] = spl_0
        @filter[cnt - 1][1] = spl_1
      end

      [spl_0, spl_1]
    end
  end

  # 2x Oversampler - wraps a processor to run at 2x sample rate
  class Oversampler2x < Processor
    FACTOR = 2

    def initialize(processor, quality: :medium)
      @processor = processor
      @upsampler = Upsampler2x.new(quality: quality)
      @downsampler = Downsampler2x.new(quality: quality)
    end

    def factor
      FACTOR
    end

    def clear!
      @processor.clear! if @processor.respond_to?(:clear!)
      @upsampler.clear!
      @downsampler.clear!
    end

    def tick(input)
      up0, up1 = @upsampler.tick(input)
      out0 = @processor.tick(up0)
      out1 = @processor.tick(up1)
      @downsampler.tick(out0, out1)
    end

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

  # 4x Oversampler using cascaded polyphase IIR halfband filters
  #
  # Uses optimized coefficient sets for two-stage 4x oversampling.
  # Each stage has coefficients tuned for its specific sample rate ratio.
  class Oversampler4x < Processor
    FACTOR = 4

    # Optimized coefficient pairs for 4x oversampling
    # Stage 1: 4x→2x rate (wider transition band allowed)
    # Stage 2: 2x→1x rate (narrower transition band needed)
    COEFS_4X = {
      # ~140 dB attenuation, 5+12 coefficients
      ultra: {
        stage1: [
          0.029113887601773612,
          0.11638402872809682,
          0.26337786480329456,
          0.47885453461538624,
          0.78984065611473109
        ].freeze,
        stage2: [
          0.021155607771239357,
          0.081229227715837876,
          0.17117329577828599,
          0.27907679095036358,
          0.39326146586620897,
          0.50450550469712818,
          0.60696304442748228,
          0.69802237610653928,
          0.77761801388575091,
          0.84744854091978927,
          0.91036460053334245,
          0.97003180383006626
        ].freeze
      },

      # ~120 dB attenuation, 4+10 coefficients
      high: {
        stage1: [
          0.041180778598107023,
          0.1665604775598164,
          0.38702422374344198,
          0.74155297339931314
        ].freeze,
        stage2: [
          0.028143361249169534,
          0.10666337918578024,
          0.22039215120527197,
          0.35084569997865528,
          0.48197792985533633,
          0.60331147102003924,
          0.7102921937907698,
          0.80307423332343497,
          0.88500411159151648,
          0.96155188130366132
        ].freeze
      },

      # ~100 dB attenuation, 3+8 coefficients (default)
      medium: {
        stage1: [
          0.064871212918289664,
          0.26990325432357809,
          0.67132720810807256
        ].freeze,
        stage2: [
          0.038927716817571831,
          0.1447065207203321,
          0.29070001093670539,
          0.44813928150889282,
          0.59667390381274976,
          0.72756709523681729,
          0.84178734600949523,
          0.94699056169241524
        ].freeze
      }
    }.freeze

    attr_reader :quality

    def initialize(processor, quality: :medium)
      @processor = processor
      @quality = quality
      coefs = COEFS_4X.fetch(quality)

      @up1 = make_filter(coefs[:stage1])
      @down1 = make_filter(coefs[:stage1])
      @up2 = make_filter(coefs[:stage2])
      @down2 = make_filter(coefs[:stage2])
    end

    def factor
      FACTOR
    end

    def clear!
      @processor.clear! if @processor.respond_to?(:clear!)
      [@up1, @up2, @down1, @down2].each do |f|
        f[:filter].each { |stage| stage[1] = 0.0 }
      end
    end

    def tick(input)
      # Upsample 1x → 2x
      s2_0, s2_1 = upsample(@up2, input)

      # Upsample 2x → 4x
      s4_0, s4_1 = upsample(@up1, s2_0)
      s4_2, s4_3 = upsample(@up1, s2_1)

      # Process at 4x rate
      out0 = @processor.tick(s4_0)
      out1 = @processor.tick(s4_1)
      out2 = @processor.tick(s4_2)
      out3 = @processor.tick(s4_3)

      # Downsample 4x → 2x
      d2_0 = downsample(@down1, out0, out1)
      d2_1 = downsample(@down1, out2, out3)

      # Downsample 2x → 1x
      downsample(@down2, d2_0, d2_1)
    end

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

    private

    def make_filter(coefs)
      nbr_coefs = coefs.size
      filter = Array.new(nbr_coefs + 2) { [0.0, 0.0] }
      coefs.each_with_index { |c, i| filter[i + 2][0] = c }
      { filter: filter, nbr_coefs: nbr_coefs }
    end

    def upsample(state, input)
      process_allpass(state, input, input)
    end

    def downsample(state, in_0, in_1)
      spl_0, spl_1 = process_allpass(state, in_1, in_0)
      (spl_0 + spl_1) * 0.5
    end

    def process_allpass(state, spl_0, spl_1)
      filter = state[:filter]
      nbr_coefs = state[:nbr_coefs]

      i = 0
      while i < nbr_coefs
        cnt = i + 2

        tmp_0 = spl_0
        tmp_0 -= filter[cnt][1]
        tmp_0 *= filter[cnt][0]
        tmp_0 += filter[cnt - 2][1]
        filter[cnt - 2][1] = spl_0

        if i + 1 < nbr_coefs
          tmp_1 = spl_1
          tmp_1 -= filter[cnt + 1][1]
          tmp_1 *= filter[cnt + 1][0]
          tmp_1 += filter[cnt - 1][1]
          filter[cnt - 1][1] = spl_1

          spl_0 = tmp_0
          spl_1 = tmp_1
          i += 2
        else
          filter[cnt - 1][1] = spl_1
          filter[cnt][1] = tmp_0
          spl_0 = tmp_0
          i += 1
        end
      end

      if nbr_coefs.even?
        cnt = nbr_coefs + 2
        filter[cnt - 2][1] = spl_0
        filter[cnt - 1][1] = spl_1
      end

      [spl_0, spl_1]
    end
  end

  # Convenience methods
  def self.oversample(processor, quality: :medium)
    Oversampler4x.new(processor, quality: quality)
  end

  def self.oversample2x(processor, quality: :medium)
    Oversampler2x.new(processor, quality: quality)
  end

  def self.oversample4x(processor, quality: :medium)
    Oversampler4x.new(processor, quality: quality)
  end

  # Wraps a complete signal chain with 4x oversampling
  class OversampledChain < Generator
    FACTOR = 4

    def initialize(quality: :medium, &block)
      @original_srate = Base.srate
      @oversampled_srate = @original_srate * FACTOR

      Base.sample_rate = @oversampled_srate
      @chain = block.call
      Base.sample_rate = @original_srate

      coefs = Oversampler4x::COEFS_4X.fetch(quality)
      @down1 = make_filter(coefs[:stage1])
      @down2 = make_filter(coefs[:stage2])
    end

    def factor
      FACTOR
    end

    def tick
      out0 = @chain.tick
      out1 = @chain.tick
      out2 = @chain.tick
      out3 = @chain.tick

      d2_0 = downsample(@down1, out0, out1)
      d2_1 = downsample(@down1, out2, out3)
      downsample(@down2, d2_0, d2_1)
    end

    def clear!
      @chain.clear! if @chain.respond_to?(:clear!)
      [@down1, @down2].each do |f|
        f[:filter].each { |stage| stage[1] = 0.0 }
      end
    end

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

    private

    def make_filter(coefs)
      nbr_coefs = coefs.size
      filter = Array.new(nbr_coefs + 2) { [0.0, 0.0] }
      coefs.each_with_index { |c, i| filter[i + 2][0] = c }
      { filter: filter, nbr_coefs: nbr_coefs }
    end

    def downsample(state, in_0, in_1)
      spl_0, spl_1 = process_allpass(state, in_1, in_0)
      (spl_0 + spl_1) * 0.5
    end

    def process_allpass(state, spl_0, spl_1)
      filter = state[:filter]
      nbr_coefs = state[:nbr_coefs]

      i = 0
      while i < nbr_coefs
        cnt = i + 2

        tmp_0 = spl_0
        tmp_0 -= filter[cnt][1]
        tmp_0 *= filter[cnt][0]
        tmp_0 += filter[cnt - 2][1]
        filter[cnt - 2][1] = spl_0

        if i + 1 < nbr_coefs
          tmp_1 = spl_1
          tmp_1 -= filter[cnt + 1][1]
          tmp_1 *= filter[cnt + 1][0]
          tmp_1 += filter[cnt - 1][1]
          filter[cnt - 1][1] = spl_1

          spl_0 = tmp_0
          spl_1 = tmp_1
          i += 2
        else
          filter[cnt - 1][1] = spl_1
          filter[cnt][1] = tmp_0
          spl_0 = tmp_0
          i += 1
        end
      end

      if nbr_coefs.even?
        cnt = nbr_coefs + 2
        filter[cnt - 2][1] = spl_0
        filter[cnt - 1][1] = spl_1
      end

      [spl_0, spl_1]
    end
  end

  # Wraps a complete signal chain with 2x oversampling
  class OversampledChain2x < Generator
    FACTOR = 2

    def initialize(quality: :medium, &block)
      @original_srate = Base.srate
      @oversampled_srate = @original_srate * FACTOR

      Base.sample_rate = @oversampled_srate
      @chain = block.call
      Base.sample_rate = @original_srate

      @downsampler = Downsampler2x.new(quality: quality)
    end

    def factor
      FACTOR
    end

    def tick
      out0 = @chain.tick
      out1 = @chain.tick
      @downsampler.tick(out0, out1)
    end

    def clear!
      @chain.clear! if @chain.respond_to?(:clear!)
      @downsampler.clear!
    end

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

  def self.oversampled(quality: :medium, &block)
    OversampledChain.new(quality: quality, &block)
  end

  def self.oversampled2x(quality: :medium, &block)
    OversampledChain2x.new(quality: quality, &block)
  end

end
