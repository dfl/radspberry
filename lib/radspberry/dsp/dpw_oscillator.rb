module DSP
  # Differentiated Parabolic Waveform (DPW) Oscillator
  # Based on Vesa Välimäki's algorithm for anti-aliased waveform generation.
  #
  # The DPW technique generates band-limited waveforms by:
  # 1. Computing a polynomial (parabolic) function of the naive waveform
  # 2. Differentiating to recover a band-limited version
  #
  # This naturally rolls off harmonics above the fundamental, reducing aliasing.
  # Reference: Välimäki, V. (2005) "Discrete-Time Synthesis of the Sawtooth Waveform
  # with Reduced Aliasing"

  class DPWSaw < PhasorOscillator
    # First-order DPW sawtooth oscillator (6dB/octave rolloff above fc)

    def initialize(freq = DEFAULT_FREQ, phase = 0)
      super
      init_state!
    end

    def clear!
      init_state!
      self
    end

    def tick
      # Get current phase and advance
      p = tock

      # Naive sawtooth: convert phase [0,1] to [-1,1]
      naive_saw = 2.0 * p - 1.0

      # Parabolic waveform: x^2
      parabola = naive_saw * naive_saw

      # Differentiate and scale
      # Scale factor: srate / (4 * freq) normalizes amplitude
      # The 4 comes from the derivative of x^2 being 2x, and the range being 2
      scale = 0.25 * srate / freq

      output = (parabola - @last_parabola) * scale
      @last_parabola = parabola

      output
    end

    private

    def init_state!
      # Initialize to avoid startup transient by computing the parabola
      # for the current phase
      p = phase
      naive_saw = 2.0 * p - 1.0
      @last_parabola = naive_saw * naive_saw
    end
  end


  class DPWPulse < PhasorOscillator
    # DPW pulse/square wave using two phase-shifted DPW saws
    # duty: 0.5 = square wave, other values = pulse wave

    param_accessor :duty, :default => 0.5, :range => (0.01..0.99)

    def initialize(freq = DEFAULT_FREQ, phase = 0)
      super
      init_state!
    end

    def clear!
      init_state!
      self
    end

    def tick
      p = tock

      # Two saws offset by duty cycle
      p2 = p + duty
      p2 -= 1.0 if p2 >= 1.0

      # Naive saws
      saw1 = 2.0 * p - 1.0
      saw2 = 2.0 * p2 - 1.0

      # Parabolas
      para1 = saw1 * saw1
      para2 = saw2 * saw2

      # Differentiate and scale
      scale = 0.25 * srate / freq

      dpw1 = (para1 - @last_p1) * scale
      dpw2 = (para2 - @last_p2) * scale

      @last_p1 = para1
      @last_p2 = para2

      # Pulse = saw1 - saw2 (normalized for unity amplitude)
      dpw1 - dpw2
    end

    private

    def init_state!
      p = phase
      p2 = p + duty
      p2 -= 1.0 if p2 >= 1.0
      saw1 = 2.0 * p - 1.0
      saw2 = 2.0 * p2 - 1.0
      @last_p1 = saw1 * saw1
      @last_p2 = saw2 * saw2
    end
  end

  class DPWTri < PhasorOscillator
    # DPW triangle wave
    # Uses the absolute value of a DPW saw to create a band-limited triangle

    def initialize(freq = DEFAULT_FREQ, phase = 0)
      super
      init_state!
    end

    def clear!
      init_state!
      self
    end

    def tick
      p = tock

      # Naive sawtooth
      naive_saw = 2.0 * p - 1.0
      parabola = naive_saw * naive_saw

      scale = 0.25 * srate / freq
      dpw_saw = (parabola - @last_parabola) * scale
      @last_parabola = parabola

      # Convert saw to triangle using absolute value transformation
      # tri = 1 - 2*|saw| (scaled from [-1,1] saw to [-1,1] triangle)
      # But we need to handle the sign correctly
      # When phase < 0.5, we're rising; when phase >= 0.5, we're falling
      1.0 - 2.0 * dpw_saw.abs
    end

    private

    def init_state!
      p = phase
      naive_saw = 2.0 * p - 1.0
      @last_parabola = naive_saw * naive_saw
    end
  end
end
