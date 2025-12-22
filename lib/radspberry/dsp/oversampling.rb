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
        # Path 0 (spl_0) uses even i (0, 2, 4...)
        # Path 1 (spl_1) uses odd i (1, 3, 5...)
        
        # Allpass: y = a*(x - y_prev) + x_prev
        
        # Path 0
        stage0 = @filter[i + 2]
        out0 = stage0[0] * (spl_0 - stage0[2]) + stage0[1]
        stage0[1] = spl_0 # update x_prev
        stage0[2] = out0  # update y_prev
        spl_0 = out0

        # Path 1
        if i + 1 < @nbr_coefs
          stage1 = @filter[i + 3]
          out1 = stage1[0] * (spl_1 - stage1[2]) + stage1[1]
          stage1[1] = spl_1
          stage1[2] = out1
          spl_1 = out1
        end
        i += 2
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
      @filter = Array.new(@nbr_coefs + 2) { [0.0, 0.0, 0.0] }
      @coefs.each_with_index { |c, i| @filter[i + 2][0] = c }
      clear!
    end

    def clear!
      @filter.each { |stage| stage[1] = stage[2] = 0.0 }
    end

    def tick(input)
      process_sample_pos(input, input)
    end

    private

    def process_sample_pos(spl_0, spl_1)
      i = 0
      while i < @nbr_coefs
        # Path 0
        stage0 = @filter[i + 2]
        out0 = stage0[0] * (spl_0 - stage0[2]) + stage0[1]
        stage0[1] = spl_0
        stage0[2] = out0
        spl_0 = out0

        # Path 1
        if i + 1 < @nbr_coefs
          stage1 = @filter[i + 3]
          out1 = stage1[0] * (spl_1 - stage1[2]) + stage1[1]
          stage1[1] = spl_1
          stage1[2] = out1
          spl_1 = out1
        end
        i += 2
      end
      [spl_0, spl_1]
    end
  end

  # 2x Downsampler using polyphase IIR halfband filter
  class Downsampler2x < Processor
    def initialize(quality: :medium)
      @coefs = PolyphaseHalfband::COEFS.fetch(quality)
      @nbr_coefs = @coefs.size
      @filter = Array.new(@nbr_coefs + 2) { [0.0, 0.0, 0.0] }
      @coefs.each_with_index { |c, i| @filter[i + 2][0] = c }
      clear!
    end

    def clear!
      @filter.each { |stage| stage[1] = stage[2] = 0.0 }
    end

    def tick(in_0, in_1 = nil)
      if in_0.is_a?(Array)
        in_1 = in_0[1]
        in_0 = in_0[0]
      end
      spl_0, spl_1 = process_sample_pos(in_1, in_0)
      (spl_0 + spl_1) * 0.5
    end

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
        # Path 0
        stage0 = @filter[i + 2]
        out0 = stage0[0] * (spl_0 - stage0[2]) + stage0[1]
        stage0[1] = spl_0
        stage0[2] = out0
        spl_0 = out0

        # Path 1
        if i + 1 < @nbr_coefs
          stage1 = @filter[i + 3]
          out1 = stage1[0] * (spl_1 - stage1[2]) + stage1[1]
          stage1[1] = spl_1
          stage1[2] = out1
          spl_1 = out1
        end
        i += 2
      end
      [spl_0, spl_1]
    end
  end

  # ... (Oversampler2x remains the same)

  module OversamplingUtils
    private
    def make_filter(coefs)
      nbr_coefs = coefs.size
      filter = Array.new(nbr_coefs + 2) { [0.0, 0.0, 0.0] }
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
        # Path 0
        stage0 = filter[i + 2]
        out0 = stage0[0] * (spl_0 - stage0[2]) + stage0[1]
        stage0[1] = spl_0
        stage0[2] = out0
        spl_0 = out0

        # Path 1
        if i + 1 < nbr_coefs
          stage1 = filter[i + 3]
          out1 = stage1[0] * (spl_1 - stage1[2]) + stage1[1]
          stage1[1] = spl_1
          stage1[2] = out1
          spl_1 = out1
        end
        i += 2
      end
      [spl_0, spl_1]
    end
  end

  # 4x Oversampler
  class Oversampler4x < Processor
    include OversamplingUtils
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

      # Adjust processor sample rate if possible
      if @processor.respond_to?(:srate=)
        @original_processor_srate = @processor.srate
        @processor.srate = Base.srate * FACTOR
        @processor.recalc if @processor.respond_to?(:recalc)
      end
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

    # method_missing/respond_to_missing? already in file
  end

  # 4x Oversampler specifically for Generators (no input)
  class GeneratorOversampler < Generator
    include OversamplingUtils
    FACTOR = 4

    def initialize(processor, quality: :medium)
      @processor = processor
      @quality = quality
      coefs = Oversampler4x::COEFS_4X.fetch(quality)

      # Only need downsampling filters
      @down1 = make_filter(coefs[:stage1])
      @down2 = make_filter(coefs[:stage2])

      # Adjust processor sample rate
      if @processor.respond_to?(:srate=)
        @processor.srate = Base.srate * FACTOR
        @processor.recalc if @processor.respond_to?(:recalc)
      end
    end

    def factor
      FACTOR
    end
    
    def clear!
      @processor.clear! if @processor.respond_to?(:clear!)
      [@down1, @down2].each do |f|
        f[:filter].each { |stage| stage[1] = 0.0 }
      end
    end

    def tick
      # Generate 4 samples at 4x rate
      out0 = @processor.tick
      out1 = @processor.tick
      out2 = @processor.tick
      out3 = @processor.tick

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
  end

  # Convenience methods
  def self.oversample(processor, quality: :medium)
    is_generator = processor.is_a?(Generator) || 
                  (processor.respond_to?(:tick) && processor.method(:tick).arity == 0)

    if is_generator
      GeneratorOversampler.new(processor, quality: quality)
    else
      Oversampler4x.new(processor, quality: quality)
    end
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


  # --- LEGACY OVERSAMPLING (Direct Form II Elliptic) ---

  # 12th order elliptic lowpass filter for 4x oversampling
  class LegacyEllipticQuarterBandFilter < Processor
    A = [-9.1891604652189471, 40.177553696870497, -110.11636661771178, 210.18506612078195, -293.84744771903240, 308.16345558359234, -244.06786780384243, 144.81877911392738, -62.770692151724198, 18.867762095902137, -3.5327094230551848, 0.31183189275203149].freeze
    B = [0.00013671732099945628, -0.00055538501265606384, 0.0013681887636296387, -0.0022158566490711852, 0.0028320091007278322, -0.0029776933151090413, 0.0030283628243514991, -0.0029776933151090413, 0.0028320091007278331, -0.0022158566490711861, 0.0013681887636296393, -0.00055538501265606384, 0.00013671732099945636].freeze

    def initialize; clear!; end
    def clear!; @w = Array.new(12, 0.0); end
    def tick(input)
      tmp = input + 1e-20
      tmp -= A[0]*@w[0] + A[1]*@w[1] + A[2]*@w[2] + A[3]*@w[3] + A[4]*@w[4] + A[5]*@w[5] + A[6]*@w[6] + A[7]*@w[7] + A[8]*@w[8] + A[9]*@w[9] + A[10]*@w[10] + A[11]*@w[11]
      y = B[0]*tmp + B[1]*@w[0] + B[2]*@w[1] + B[3]*@w[2] + B[4]*@w[3] + B[5]*@w[4] + B[6]*@w[5] + B[7]*@w[6] + B[8]*@w[7] + B[9]*@w[8] + B[10]*@w[9] + B[11]*@w[10] + B[12]*@w[11]
      11.downto(1) { |i| @w[i] = @w[i-1] }; @w[0] = tmp; y
    end
  end

  class LegacyOversampler < Processor
    FACTOR = 4
    def initialize(processor)
      @processor = processor
      @upsample_filter = LegacyEllipticQuarterBandFilter.new
      @downsample_filter = LegacyEllipticQuarterBandFilter.new
    end
    def clear!
      @processor.clear! if @processor.respond_to?(:clear!)
      @upsample_filter.clear!; @downsample_filter.clear!
    end
    def tick(input)
      up0 = @upsample_filter.tick(input * FACTOR)
      up1 = @upsample_filter.tick(0.0); up2 = @upsample_filter.tick(0.0); up3 = @upsample_filter.tick(0.0)
      out0 = @processor.tick(up0); out1 = @processor.tick(up1); out2 = @processor.tick(up2); out3 = @processor.tick(up3)
      @downsample_filter.tick(out0); @downsample_filter.tick(out1); @downsample_filter.tick(out2)
      @downsample_filter.tick(out3)
    end
    def method_missing(m, *a, &b); @processor.respond_to?(m) ? @processor.send(m, *a, &b) : super; end
    def respond_to_missing?(m, i = false); @processor.respond_to?(m, i) || super; end
  end

end
