module DSP
  extend self

  module Constants
    PI        = ::Math::PI
    PI_2      = 0.5*PI
    TWO_PI    = 2.0*PI
    SQRT2     = ::Math.sqrt(2)
    SQRT2_2   = 0.5*::Math.sqrt(2)
  end
  include Constants

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

    def exp x
      ::Math.exp x
    end

  end

  # http://www.kvraudio.com/forum/viewtopic.php?t=349859
  def ptan1 x  # Pade tan #1
    x2 = x*x
    (-15.0*x+x2*x) / (3.0*(-5.0+2.0*x2))
  end
  
  def ptan2 x
    x2 = x*x;
    5.0*(-21.0*x+2.0*x2*x) / (105.0 - 45.0*x2+x2*x2 )
  end
  
  # mystran's nonlinearity
  def tanhXdX x
    # IIRC I got this as Pade-approx for tanh(sqrt(x))/sqrt(x) 
    x2 = x*x;
    ((x2 + 105.0)*x2 + 945.0) / ((15.0*x2 + 420.0)*x2 + 945.0)
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

  def xfade( a, b, x )  # AKA lerp
    (b-a)*x + a
  end

  def quart(x)
    tmp = x*x
    tmp*tmp
  end

  def saturate x, y=0.25
    1.0 - y*x.abs
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

  def clamp x, min=(0.0..1.0), max=nil
    min,max = min.first, min.last if min.is_a?(Range)
    [min, x, max].sort[1]
  end

  class LookupTable  # linear interpolated, input goes from 0 to 1
    def initialize opts={}
      opts.reverse_merge! :bits => 7, :scale => 1.0, :offset => 0
      @size, @scale, @offset  = 2 ** opts[:bits], opts[:scale], opts[:offset]
      @table = @size.times.map{|x| yield( x.to_f / @size ) }
    end

    def []( arg )  # input goes from 0 to 1
      offset = arg * @size
      idx = offset.floor
      frac = offset - idx
      output = idx >= @size - 1 ? @table.last : DSP.xfade( @table[idx], @table[idx+1], frac )
      # output = @scale * output + offset
    end
  end
  
end
