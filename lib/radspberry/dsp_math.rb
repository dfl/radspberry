module DSP
  module Constants
    PI        = ::Math::PI
    PI_2      = 0.5*PI
    TWO_PI    = 2.0*PI
    SQRT2     = ::Math.sqrt(2)
    SQRT2_2   = 0.5*::Math.sqrt(2)
  end
  include Constants

  extend self
  module Math  # TODO make lookup tables?
    def sin x
      ::Math.sin x
    end

    def cos x
      ::Math.cos x
    end

    def tan x
      ::Math.tan x
    end
  end

  def noise
    bipolar( random )
  end

  def random
    rand # Random.rand
  end

  def bipolar x
    2.0*x - 1.0
  end

  def xfade( a, b, x )
    (b-a)*x + a
  end

  def quart(x)
    tmp = x*x
    tmp*tmp
  end

  # def crush x, bits=8
  #   step = 2**-bits
  #   step * (x * step + 0.5).floor
  # end
  def quant2 x, step
    step * (x * step + 0.5).floor
  end

  def quantize val, nearest
    (val.to_f / nearest.to_f).ceil * nearest
  end

  def clamp x, min, max
    [min, x, max].sort[1]
  end

  class LookupTable  # linear interpolated, input goes from 0 to 1
    def initialize bits=7
      @size  = 2 ** bits
      scale  = 1.0 / @size
      @table = (0..@size).map{|x| yield( scale * x ) }
    end

    def []( arg )  # from 0 to 1
      offset = arg * @size
      idx = offset.floor
      frac = offset - idx
      return @table.last if idx >= @size
      DSP.xfade( @table[idx], @table[idx+1], frac )
    end
  end

end