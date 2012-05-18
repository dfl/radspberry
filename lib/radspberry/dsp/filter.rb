module DSP

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
      @b,@a = b,a
      if @interpolate
        @_b,@_a = @b,@a
        interpolate if interpolating?
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

    def freq= arg
      @w0 = TWO_PI * arg * inv_srate # normalize freq [0,PI)
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

  class Hpf < Biquad
    def initialize( f, q=nil )
      @interpolate = true
      @inv_q = q ? 1.0 / q : SQRT2  # default to butterworth
      self.freq = f # triggers recalc
      clear
    end

    def q= arg
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
end