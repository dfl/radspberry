module DSP

  # http://www.kvraudio.com/forum/viewtopic.php?t=333887
  class OnePoleZD < Processor
    attr_accessor :state
    include Math
    
    def initialize
      freq = srate / 2.0
    end
    
    def freq= freq
      @f    = tan( PI * freq * inv_srate )  # BLT... should be 2x oversampled
      @finv = 1.0 / (1.0 + @f)
    end

    def clear 
      @state = 0.0
    end
  end
  
  class ZDLP < OnePoleZD
    attr_accessor :state
    include Math
    
    def initialize
      freq = srate / 2.0
    end
    
    def freq= freq
      @f    = tan( PI * freq * inv_srate )  # BLT... should be 2x oversampled
      @finv = 1.0 / (1.0 + @f)
    end

    def clear 
      @state = 0.0
    end

    def tick input  # zero delay feedback
      output = (@state + @f * input ) * @finv;
      @state = @f * (input - output) + output
      output
      # iin = input - (@state + @f * input) / @finv
      # output = @state + @f*iin
      # @state = @f * iin + output
    end
  end

  class ZDHP < OnePoleZD
    def tick input  
      low    = (@state + @f * input ) * @finv;
      high   = input - low
      @state = low + @f * high
      high
    end
  end

  class Biquad < Processor  # interpolating biquad, Direct-form 1
    include Math

    def initialize( num=[1.0,0,0], den=[1.0,0,0], opts={} )
      @interpolate = opts[:interpolate]
      @denorm = ANTI_DENORMAL
      update( Vector[*num], Vector[*den] )
      normalize if @a[0] != 1.0
      clear
    end

    def normalize  # what about b0 (gain)
      inv = 1.0 / @a[0]
      @b *= inv
      @a *= inv
    end
  
    def clear
      @input  = [0,0,0]
      @output = [0,0,0]
      stop_interpolation
    end

    def process input, b=@b, a=@a  # default to normal state
      output = b[0]*input + b[1]*@input[1] + b[2]*@input[2]
      output -= a[1]*@output[1] + a[2]*@output[2]
      @input[2]  = @input[1]
      @input[1]  = input + ANTI_DENORMAL # TODO: oscillate at nyquist?  +1, 0, +1, 0
      @output[2] = @output[1]
      @output[1] = output 
    end
  
    def update b, a
      if @interpolate && @b && @a  # Only save old values if they exist
        @_b,@_a = @b,@a  # Save old values before updating
      end
      @b,@a = b,a  # Update to new values
      if @interpolate && @_b && @_a  # Only interpolate if we have old values
        interpolate  # Interpolate from old to new
      end
    end

    def interpolate # TODO: interpolate over VST sample frame ?
      @interp_period = (srate * 1e-3).floor  # 1ms
      t = 1.0 / @interp_period
      @delta_b = (@b - @_b) * t
      @delta_a = (@a - @_a) * t
      @interp_ticks = 0
    end

    def interpolating?
      @_b && @_a
    end

    def stop_interpolation
      @_b = @_a = nil
    end

    def tick input
      if interpolating?  # process with interpolated state
        @_b += @delta_b
        @_a += @delta_a
        process( input, @_b, @_a ).tap do
          stop_interpolation if (@interp_ticks += 1) >= @interp_period
        end
      else
        process( input )
      end
    end

    attr_reader :freq
    def freq=(arg)
      @freq = arg
      @w0 = TWO_PI * @freq * inv_srate # normalize freq [0,PI)
      recalc
    end
  end

  class Biquad2 < Biquad # DFII
    def clear
      @state = [0,0]
      stop_interpolation
    end

    def process
      output = b[0]*input + @state[0] + ANTI_DENORMAL
      @state[0] = b[1]*input - a[1]*output + @state[1] 
      @state[1] = b[2]*input - a[2]*output
    end  
  end

  class ButterHP < Biquad
    def initialize( f=100, q: nil )
      super( [1.0,0,0], [1.0,0,0], interpolate: true )
      @inv_q = q ? 1.0 / q : SQRT2  # default to butterworth
      self.freq = f # triggers recalc
    end

    def q
      1.0 / @inv_q
    end

    def q=(arg)
      @inv_q = 1.0 / arg
      # inv_q = 10.0**(-0.05*rez);
      recalc
    end

    def recalc
      # from RBJ cookbook @ http://www.musicdsp.org/files/Audio-EQ-Cookbook.txt
      # alpha = 0.5 * @inv_q * sin(@w0)
      # cw = cos(@w0)
      # gamma = 1+cw
      # b0 = b2 = 0.5*gamma
      # b1 = -gamma    
      # a0 = 1 + alpha
      # a1 = -2.0*cw
      # a2 = 1 - alpha

      # from /Developer/Examples/CoreAudio/AudioUnits/AUPinkNoise/Utility/Biquad.cpp 
      temp = 0.5 * @inv_q * sin( @w0 );
      beta = 0.5 * (1.0 - temp) / (1.0 + temp);
      gamma = (0.5 + beta) * cos( @w0 );
      alpha = (0.5 + beta + gamma) * 0.25;

      b0 = 2.0 *   alpha;
      b1 = 2.0 *   -2.0 * alpha;
      b2 = 2.0 *   alpha;
      a0 = 1.0
      a1 = 2.0 *   -gamma;
      a2 = 2.0 *   beta;

      update( Vector[b0, b1, b2], Vector[a0, a1, a2] )
      normalize if @a[0] != 1.0
    end

  end

  class ButterLP < ButterHP
    def recalc
      # Using formula from https://www.earlevel.com/main/2012/11/26/biquad-c-source-code/
      k = tan(PI * @freq * inv_srate)
      norm = 1.0 / (1.0 + k * @inv_q + k * k)

      b0 = k * k * norm
      b1 = 2.0 * b0
      b2 = b0
      a0 = 1.0
      a1 = 2.0 * (k * k - 1.0) * norm
      a2 = (1.0 - k * @inv_q + k * k) * norm

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end

  class ButterBP < ButterHP
    def recalc
      # Bandpass filter from https://www.earlevel.com/main/2012/11/26/biquad-c-source-code/
      # Modified for constant 0dB peak gain (multiply by Q for resonance)
      k = tan(PI * @freq * inv_srate)
      norm = 1.0 / (1.0 + k * @inv_q + k * k)

      # Original: b0 = k * @inv_q * norm (constant skirt gain)
      # Modified: b0 = k * norm (constant peak gain - more resonant)
      b0 = k * norm
      b1 = 0.0
      b2 = -b0
      a0 = 1.0
      a1 = 2.0 * (k * k - 1.0) * norm
      a2 = (1.0 - k * @inv_q + k * k) * norm

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end

  class ButterNotch < ButterHP
    def recalc
      # Notch filter from https://www.earlevel.com/main/2012/11/26/biquad-c-source-code/
      k = tan(PI * @freq * inv_srate)
      norm = 1.0 / (1.0 + k * @inv_q + k * k)

      b0 = (1.0 + k * k) * norm
      b1 = 2.0 * (k * k - 1.0) * norm
      b2 = b0
      a0 = 1.0
      a1 = b1
      a2 = (1.0 - k * @inv_q + k * k) * norm

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end

  class ButterPeak < ButterHP
    param_accessor :gain, :default => 0.0, :after_set => Proc.new{recalc}

    def initialize( f=1000, q: nil, gain: 0.0 )
      @gain = gain  # Set gain before super to avoid nil in recalc
      super(f, q: q)
    end

    def recalc
      # Peaking EQ from https://www.earlevel.com/main/2012/11/26/biquad-c-source-code/
      k = tan(PI * @freq * inv_srate)
      v = 10.0 ** (@gain.abs / 20.0)

      if @gain >= 0.0
        # Boost
        norm = 1.0 / (1.0 + @inv_q * k + k * k)
        b0 = (1.0 + v * @inv_q * k + k * k) * norm
        b1 = 2.0 * (k * k - 1.0) * norm
        b2 = (1.0 - v * @inv_q * k + k * k) * norm
        a0 = 1.0
        a1 = b1
        a2 = (1.0 - @inv_q * k + k * k) * norm
      else
        # Cut
        norm = 1.0 / (1.0 + v * @inv_q * k + k * k)
        b0 = (1.0 + @inv_q * k + k * k) * norm
        b1 = 2.0 * (k * k - 1.0) * norm
        b2 = (1.0 - @inv_q * k + k * k) * norm
        a0 = 1.0
        a1 = b1
        a2 = (1.0 - v * @inv_q * k + k * k) * norm
      end

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end

  class ButterLowShelf < ButterHP
    param_accessor :gain, :default => 0.0, :after_set => Proc.new{recalc}

    def initialize( f=1000, q: nil, gain: 0.0 )
      @gain = gain  # Set gain before super to avoid nil in recalc
      super(f, q: q)
    end

    def recalc
      # Low shelf from https://www.earlevel.com/main/2012/11/26/biquad-c-source-code/
      k = tan(PI * @freq * inv_srate)
      v = 10.0 ** (@gain.abs / 20.0)

      if @gain >= 0.0
        # Boost
        norm = 1.0 / (1.0 + SQRT2 * k + k * k)
        b0 = (1.0 + ::Math.sqrt(2.0 * v) * k + v * k * k) * norm
        b1 = 2.0 * (v * k * k - 1.0) * norm
        b2 = (1.0 - ::Math.sqrt(2.0 * v) * k + v * k * k) * norm
        a0 = 1.0
        a1 = 2.0 * (k * k - 1.0) * norm
        a2 = (1.0 - SQRT2 * k + k * k) * norm
      else
        # Cut
        norm = 1.0 / (1.0 + ::Math.sqrt(2.0 * v) * k + v * k * k)
        b0 = (1.0 + SQRT2 * k + k * k) * norm
        b1 = 2.0 * (k * k - 1.0) * norm
        b2 = (1.0 - SQRT2 * k + k * k) * norm
        a0 = 1.0
        a1 = 2.0 * (v * k * k - 1.0) * norm
        a2 = (1.0 - ::Math.sqrt(2.0 * v) * k + v * k * k) * norm
      end

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end

  class ButterHighShelf < ButterHP
    param_accessor :gain, :default => 0.0, :after_set => Proc.new{recalc}

    def initialize( f=1000, q: nil, gain: 0.0 )
      @gain = gain  # Set gain before super to avoid nil in recalc
      super(f, q: q)
    end

    def recalc
      # High shelf from https://www.earlevel.com/main/2012/11/26/biquad-c-source-code/
      k = tan(PI * @freq * inv_srate)
      v = 10.0 ** (@gain.abs / 20.0)

      if @gain >= 0.0
        # Boost
        norm = 1.0 / (1.0 + SQRT2 * k + k * k)
        b0 = (v + ::Math.sqrt(2.0 * v) * k + k * k) * norm
        b1 = 2.0 * (k * k - v) * norm
        b2 = (v - ::Math.sqrt(2.0 * v) * k + k * k) * norm
        a0 = 1.0
        a1 = 2.0 * (k * k - 1.0) * norm
        a2 = (1.0 - SQRT2 * k + k * k) * norm
      else
        # Cut
        norm = 1.0 / (v + ::Math.sqrt(2.0 * v) * k + k * k)
        b0 = (1.0 + SQRT2 * k + k * k) * norm
        b1 = 2.0 * (k * k - 1.0) * norm
        b2 = (1.0 - SQRT2 * k + k * k) * norm
        a0 = 1.0
        a1 = 2.0 * (k * k - v) * norm
        a2 = (v - ::Math.sqrt(2.0 * v) * k + k * k) * norm
      end

      update(Vector[b0, b1, b2], Vector[a0, a1, a2])
    end
  end


  # high shelf
    # float gain = inDbGain;
    # 
    # 
    #     float sn    = sin(omega);
    #     float cs    = cos(omega);
    # 
    # float S = 1.0;
    #     float A     =  pow(10.0, (gain * 0.025 ) );
    # 
    # float Am = A - 1.0;
    # float Ap = A + 1.0;
    #     float beta  = sqrt( (A*A + 1.0)/S - Am*Am );
    # 
    #     float b0 =    A*( Ap + Am*cs + beta*sn );
    #     float b1 = -2*A*( Am + Ap*cs           );
    #     float b2 =    A*( Ap + Am*cs - beta*sn );
    #     float a0 =        Ap - Am*cs + beta*sn;
    #     float a1 =    2*( Am - Ap*cs           );
    #     float a2 =        Ap - Am*cs - beta*sn;
    
    
  # http://www.cytomic.com/files/dsp/SvfLinearTrapOptimised.pdf
  class SVF < Processor
    attr_accessor :kind, :freq

    def initialize(kind: :low)
      @kind = kind
      clear
    end

    def clear
      @v0z = 0
      @v1  = 0
      @v2  = 0
      @output = {}
    end
    
    def freq= f
      @freq = freq
      recalc
    end

    def q= q
      @q = q
      recalc
    end
    
    def recalc
      @g = tan( PI * @freq * inv_srate )
      @k = 1.0 / @q
      @ginv = @g / ( 1.0 + @g * (@g+@k))
      @g1 = @ginv
      @g2 = 2.0 * (@g+@k) * @ginv
      @g3 = @g * @ginv
      @g4 = 2.0 * @ginv
    end

    def process(input)
      @v0  = input
      @v1z = @v1
      @v2z = @v2
      @v3  = @v0 + @v0z - 2.0 * @v2z
      @v1 += @g1 * @v3 - @g2 * @v1z
      @v2 += @g3 * @v3 + @g4 * @v1z
      @v0z = @v0
      @output[:lp]    = @v2
      @output[:bp]    = @v1
      @output[:hp]    = @v0 - @k * @v1 - @v2
      @output[:notch] = @v0 - @k * @v1
    end

    def tick input
      process( input )
      output[ @kind ]
    end
  end
  
  class BellSVF < SVF
    def recalc
      @gb   = 10.0 ** (dbGain * 0.025)
      @g    = tan( PI * @freq * inv_srate )
      @k    = 1.0 / (@q * @gb)
      @gi   = @k * (@gb * @gb - 1)
      @ginv = @g / ( 1.0 + @g * (@g+@k))
      @g1   = @ginv
      @g2   = 2.0 * (@g+@k) * @ginv
      @g3   = @g * @ginv
      @g4   = 2.0 * @ginv
    end
    
    def tick(input)
      @v0  = @gi * input
      @v1z = @v1
      @v2z = @v2
      @v3  = @v0 + @v0z - 2.0 * @v2z
      @v1 += @g1 * @v3 - @g2 * @v1z
      @v2 += @g3 * @v3 + @g4 * @v1z
      @v0z = @v0
      @output  = input + @v1
    end
  end
    
end

# http://www.kvraudio.com/forum/viewtopic.php?t=349859&postdays=0&postorder=asc&start=120
# Richard_Synapse
# KVRist
# - profile
# - pm
#  Posted: Thu May 24, 2012 4:45 am reply with quote
# Just for the lulz...here's a first simple model I cooked up using mystrans method. It's a 2-pole lowpass filter with nonlinear feedback, inspired by the Korg MS stuff. 
# 
# This filter has some sweet spots (I really dig the sound of its self-oscillation), but it needs work. The differential equations I used as a starting point are: 
# 
# dy1/dt = f*(in - y1 - g(r*y2)) 
# dy2/dt = f*(y1 - y2 + g(r*y2)) 
# 
# where 'r' is resonance, 'g()' is the nonlinear function. Certainly additional equations are needed to improve the sound, I keep it as simple as possible. Any suggestions welcome! 
# 
# The code: 
# Quote:
# 
# // evaluate the non-linear gain 
# double t = tanhXdX(r * yl2); 
# 
# // solve the linearized system 
# double denom = f* f * r* t + f *(f + 1) + f + 1; 
# double y1 =(-f* r *t *yl2 + (f + 1)* yl1 + f* (f + 1)* in) / denom; 
# double y2 = (f* yl2 + yl2 + f * yl1 + f* f* in) / denom; 
# 
# // update state 
# yl1 += f*2 * (in - y1 - r*t*y2); 
# yl2 += f*2 * (y1 + r*t*y2 - y2); 
# 
# 
# 
# 
# karrikuh Posted: Thu May 24, 2012 6:27 am
#  
# Richard_Synapse wrote:
# // evaluate the non-linear gain 
# double t = tanhXdX(r * yl2); 
# 
# 
# This is not strictly in accordance with your equations. Your code realizes a filter with the resonance gain r pre-saturator, while your equations have r at the output of g(). 
# Richard_Synapse wrote:
# // solve the linearized system 
# double denom = f* f * r* t + f *(f + 1) + f + 1; 
# double y1 =(-f* r *t *yl2 + (f + 1)* yl1 + f* (f + 1)* in) / denom; 
# double y2 = (f* yl2 + yl2 + f * yl1 + f* f*  in) / denom;
# 
# 
# You don't need solve the whole feedback loop for both integrator outputs. Instead, just solve for y2, then all inputs for the first lowpass stage are available and you can compute y1 in the traditional way (probably cheaper).
# ----