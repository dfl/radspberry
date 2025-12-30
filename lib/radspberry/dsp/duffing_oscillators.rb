module DSP

  # ============================================================================
  # DUFFING-RPM OSCILLATOR VARIANTS
  # ============================================================================
  #
  # Three structural approaches to combining Duffing nonlinearity with
  # Yamaha-style Recursive Phase Modulation (RPM).
  #
  # Duffing nonlinearity: ω_eff = ω₀ + α·y²  (amplitude-dependent frequency)
  # RPM nonlinearity: y = sin(φ + β·state)   (state-dependent phase)
  #
  # Reference: The Duffing equation is a second-order nonlinear ODE:
  #   ẍ + δẋ + αx + βx³ = γcos(ωt)
  # In discrete form as a resonator with amplitude-dependent pitch.
  # ============================================================================

  # Option A: Duffing-Controlled Phase Increment
  #
  # Instead of modulating the phase argument (like classic RPM), modulate the
  # phase increment itself based on amplitude squared. This gives exact
  # Duffing-style hardening/softening while preserving Yamaha PM tone.
  #
  # Properties:
  # - Amplitude-dependent pitch drift (like acoustic instruments)
  # - Brass-like "bloom" at high amplitudes
  # - Stable if alpha is small and band-limited
  #
  class DuffingPhaseRPM < Oscillator
    include DSP::Math

    RPM_CUTOFF = 5000.0

    param_accessor :beta,         :default => 1.5,    :range => (0.0..5.0)
    param_accessor :alpha,        :default => 0.005,  :range => (-0.05..0.05)  # Duffing coefficient
    param_accessor :energy_smooth,:default => 0.99,   :range => (0.9..0.9999)  # Energy smoothing

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.5
      @alpha = 0.005
      @energy_smooth = 0.99
      @lp_alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @omega0 = TWO_PI * @freq * inv_srate  # Base angular frequency increment
    end

    def clear!
      @phase = 0.0
      @state = 0.0
      @last_out = 0.0
      @energy = 0.0
    end

    def tick
      # 1. Smooth energy tracking (low-pass filtered squared amplitude)
      @energy = @energy_smooth * @energy + (1.0 - @energy_smooth) * (@last_out * @last_out)

      # 2. Duffing: amplitude-dependent frequency modulation
      # Positive alpha = hardening spring (pitch rises with amplitude)
      # Negative alpha = softening spring (pitch falls with amplitude)
      omega_eff = @omega0 + @alpha * @energy

      # Clamp omega_eff to [0, π] for stability
      omega_eff = [[omega_eff, 0.0].max, PI].min

      # 3. RPM state update (one-pole averager)
      @state += @lp_alpha * (@last_out - @state)

      # 4. Phase increment with Duffing modulation + RPM feedback
      @phase += omega_eff + @beta * @state * 0.01  # Scale state contribution
      @phase -= TWO_PI while @phase >= TWO_PI
      @phase += TWO_PI while @phase < 0.0

      # 5. Output
      @last_out = sin(@phase)
    end

    def srate=(rate)
      super
      @lp_alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      self.freq = @freq  # Recalc omega0
    end
  end


  # Option B: Duffing Resonator as Feedback Path
  #
  # Insert a true 2nd-order Duffing resonator inside the RPM feedback loop.
  # The resonator provides "cavity" behavior with nonlinear frequency.
  #
  # Properties:
  # - True nonlinear cavity behavior
  # - Blow-up → chaos → collapse regimes
  # - Extremely "physical" FM timbre (like waveguide models)
  # - Most powerful but least stable
  #
  class DuffingResonatorRPM < Oscillator
    include DSP::Math

    param_accessor :beta,         :default => 1.0,    :range => (0.0..5.0)
    param_accessor :alpha,        :default => 0.001,  :range => (0.0..0.02)   # Duffing coefficient
    param_accessor :res_freq,     :default => 1000.0, :range => (20.0..8000.0) # Resonator frequency
    param_accessor :res_r,        :default => 0.995,  :range => (0.9..0.9999)  # Resonator damping (r)
    param_accessor :res_drive,    :default => 0.5,    :range => (0.0..2.0)     # Input drive to resonator

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.0
      @alpha = 0.001
      @res_freq = 1000.0
      @res_r = 0.995
      @res_drive = 0.5
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @phase_inc = @freq * inv_srate
      update_resonator_coeffs
    end

    def res_freq=(f)
      @res_freq = f.to_f
      update_resonator_coeffs
    end

    def clear!
      @phase = 0.0
      @last_out = 0.0
      # Duffing resonator state (2nd order)
      @y1 = 0.0  # y[n-1]
      @y2 = 0.0  # y[n-2]
      @omega0_res = TWO_PI * @res_freq * inv_srate
    end

    def tick
      # 1. Duffing resonator with amplitude-dependent frequency
      # y[n] = 2r·cos(ω_eff)·y[n-1] - r²·y[n-2] + x[n]
      # ω_eff = ω₀ + α·y[n-1]²

      omega_eff = @omega0_res + @alpha * @y1 * @y1
      omega_eff = [[omega_eff, 0.0].max, PI].min  # Stability clamp

      a1 = 2.0 * @res_r * cos(omega_eff)
      a2 = -@res_r * @res_r

      # Feed RPM output into resonator
      resonator_input = @last_out * @res_drive
      y_new = a1 * @y1 + a2 * @y2 + resonator_input

      # Soft clip resonator to prevent blow-up
      y_new = DSP.fast_tanh(y_new)

      # Shift resonator delay line
      @y2 = @y1
      @y1 = y_new

      # 2. RPM oscillator using resonator output as feedback
      @phase += @phase_inc
      @phase -= 1.0 if @phase >= 1.0

      @last_out = sin(TWO_PI * @phase + @beta * @y1)
    end

    def srate=(rate)
      super
      self.freq = @freq
      update_resonator_coeffs
    end

    private

    def update_resonator_coeffs
      @omega0_res = TWO_PI * @res_freq * inv_srate
    end
  end


  # Option C: Duffing Energy-Modulated Beta (Minimal Change)
  #
  # Modify the existing RPM state nonlinearity by making beta depend on
  # state energy. This is not a true Duffing oscillator, but captures
  # the same perceptual effect with minimal CPU cost.
  #
  # Properties:
  # - Hardening/softening RPM timbre
  # - No new state variables
  # - Very cheap CPU
  # - Most stable of the three options
  #
  class DuffingEnergyRPM < Oscillator
    include DSP::Math

    RPM_CUTOFF = 5000.0

    param_accessor :beta,         :default => 1.5,    :range => (0.0..5.0)
    param_accessor :alpha,        :default => 2.0,    :range => (-10.0..10.0)  # Energy→beta modulation
    param_accessor :exponent,     :default => 1.0,    :range => (0.5..3.0)     # State feedback exponent
    param_accessor :energy_smooth,:default => 0.99,   :range => (0.9..0.9999)

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.5
      @alpha = 2.0
      @exponent = 1.0
      @energy_smooth = 0.99
      @lp_alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @phase_inc = @freq * inv_srate
    end

    def clear!
      @phase = 0.0
      @state = 0.0
      @last_out = 0.0
      @energy = 0.0
    end

    def tick
      # 1. Track state energy (smoothed)
      @energy = @energy_smooth * @energy + (1.0 - @energy_smooth) * (@state * @state)

      # 2. Duffing-style beta modulation
      # Positive alpha: louder = more harmonic content (hardening)
      # Negative alpha: louder = less harmonic content (softening)
      beta_eff = @beta + @alpha * @energy

      # 3. RPM state update with optional exponent
      fb_signal = if @exponent == 1.0
        @last_out
      else
        # Signed power: preserves sign while applying exponent
        sign = @last_out >= 0 ? 1.0 : -1.0
        sign * (@last_out.abs ** @exponent)
      end

      @state += @lp_alpha * (fb_signal - @state)

      # 4. Phase accumulator
      @phase += @phase_inc
      @phase -= 1.0 if @phase >= 1.0

      # 5. RPM output with energy-modulated beta
      @last_out = sin(TWO_PI * @phase + beta_eff * @state)
    end

    def srate=(rate)
      super
      @lp_alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      self.freq = @freq
    end
  end


  # ============================================================================
  # COMBINED DUFFING-RPM (Full Implementation)
  # ============================================================================
  #
  # A comprehensive oscillator combining all three approaches with morphable
  # control. This is the "kitchen sink" version for maximum experimentation.
  #
  class DuffingRPMOscillator < Oscillator
    include DSP::Math

    RPM_CUTOFF = 5000.0

    # Core RPM parameters
    param_accessor :beta,           :default => 1.5,    :range => (0.0..5.0)
    param_accessor :morph,          :default => 0.0,    :range => (0.0..1.0)   # Saw↔Square

    # Duffing parameters
    param_accessor :duff_alpha,     :default => 0.005,  :range => (-0.05..0.05) # Phase increment mod
    param_accessor :duff_beta,      :default => 0.0,    :range => (-10.0..10.0) # Energy→beta mod

    # Resonator parameters
    attr_accessor :res_enable  # Boolean: enable Duffing resonator
    param_accessor :res_freq,       :default => 1000.0, :range => (20.0..8000.0)
    param_accessor :res_r,          :default => 0.995,  :range => (0.9..0.9999)
    param_accessor :res_alpha,      :default => 0.001,  :range => (0.0..0.02)
    param_accessor :res_mix,        :default => 0.5,    :range => (0.0..1.0)

    # Smoothing
    param_accessor :energy_smooth,  :default => 0.99,   :range => (0.9..0.9999)

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.5
      @morph = 0.0
      @duff_alpha = 0.005
      @duff_beta = 0.0
      @res_enable = false
      @res_freq = 1000.0
      @res_r = 0.995
      @res_alpha = 0.001
      @res_mix = 0.5
      @energy_smooth = 0.99
      @lp_alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @omega0 = TWO_PI * @freq * inv_srate
      @phase_inc = @freq * inv_srate
      @omega0_res = TWO_PI * @res_freq * inv_srate
    end

    def res_freq=(f)
      @res_freq = f.to_f
      @omega0_res = TWO_PI * @res_freq * inv_srate
    end

    def clear!
      @phase = 0.0
      @state = 0.0
      @last_out = 0.0
      @energy = 0.0
      @y1 = 0.0
      @y2 = 0.0
    end

    def tick
      # 1. Energy tracking
      @energy = @energy_smooth * @energy + (1.0 - @energy_smooth) * (@last_out * @last_out)

      # 2. Option A: Duffing phase increment
      omega_eff = @omega0 + @duff_alpha * @energy
      omega_eff = [[omega_eff, 0.0].max, PI].min

      # 3. Option B: Duffing resonator (if enabled)
      res_contribution = 0.0
      if @res_enable
        res_omega = @omega0_res + @res_alpha * @y1 * @y1
        res_omega = [[res_omega, 0.0].max, PI].min

        a1 = 2.0 * @res_r * cos(res_omega)
        a2 = -@res_r * @res_r

        y_new = a1 * @y1 + a2 * @y2 + @last_out * 0.1
        y_new = DSP.fast_tanh(y_new)

        @y2 = @y1
        @y1 = y_new
        res_contribution = @y1 * @res_mix
      end

      # 4. Option C: Energy-modulated beta
      beta_eff = @beta + @duff_beta * @energy

      # 5. Morphable RPM state update
      fb_signal = (@last_out * @last_out - @last_out) * @morph + @last_out
      @state += @lp_alpha * (fb_signal - @state)

      # 6. Combined phase with all contributions
      @phase += omega_eff / TWO_PI  # Convert back to normalized phase
      @phase -= 1.0 while @phase >= 1.0
      @phase += 1.0 while @phase < 0.0

      # 7. Final RPM output with resonator mix
      eff_beta = beta_eff * (1.0 - 2.0 * @morph)
      @last_out = sin(TWO_PI * @phase + eff_beta * @state + res_contribution * @beta)
    end

    def srate=(rate)
      super
      @lp_alpha = 1.0 - ::Math.exp(-TWO_PI * RPM_CUTOFF * inv_srate)
      self.freq = @freq
    end
  end


  # ============================================================================
  # CURVED RPM OSCILLATOR - Spectral Curvature without Pitch Instability
  # ============================================================================
  #
  # A fundamentally different approach from the Duffing oscillators above:
  #
  # - Fundamental phase is STRICTLY STABLE (never modulated)
  # - Recursive feedback never modulates base frequency
  # - Nonlinearity only bends PARTIAL GEOMETRY
  # - One primary parameter: spectral curvature
  # - Optional secondary: amplitude-dependent evolution
  #
  # This produces Duffing-like spectral effects without pitch drift or chaos.
  # The ear interprets this as "material" or "resonator" character changes.
  #
  # Perceptual model:
  #   curvature > 0 → hardening spectrum (partials spread upward, like brass)
  #   curvature < 0 → softening spectrum (partials collapse inward)
  #   curvature = 0 → standard harmonic series
  #
  # This matches how acoustic instruments behave:
  #   - Brass instruments "open up" with amplitude
  #   - Strings stiffen with amplitude
  #   - Acoustic cavities have amplitude-dependent resonance
  #
  class CurvedRPMOscillator < Oscillator
    include DSP::Math

    # Primary parameters
    param_accessor :curvature,    :default => 0.0,   :range => (-1.0..1.0)   # Spectral curvature (primary timbre)
    param_accessor :beta,         :default => 0.3,   :range => (0.0..0.8)    # RPM depth (partial motion)
    param_accessor :evolve,       :default => 0.0,   :range => (0.0..1.0)    # Amplitude→curvature coupling
    param_accessor :damp,         :default => 0.99,  :range => (0.95..0.999) # State smoothing

    # Harmonic mix (relative amplitudes of partials 2, 3, 4, 5)
    param_accessor :h2_amp,       :default => 0.25,  :range => (0.0..1.0)
    param_accessor :h3_amp,       :default => 0.11,  :range => (0.0..1.0)
    param_accessor :h4_amp,       :default => 0.06,  :range => (0.0..1.0)
    param_accessor :h5_amp,       :default => 0.03,  :range => (0.0..1.0)

    def initialize(freq = DEFAULT_FREQ)
      @curvature = 0.0
      @beta = 0.3
      @evolve = 0.0
      @damp = 0.99
      @h2_amp = 0.25
      @h3_amp = 0.11
      @h4_amp = 0.06
      @h5_amp = 0.03
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @omega = TWO_PI * @freq * inv_srate
    end

    def clear!
      @phase = 0.0
      @energy = 0.0
      @fb_state = 0.0
    end

    def tick
      # 1. Advance fundamental phase (NEVER nonlinear - this is the pitch anchor)
      @phase += @omega
      @phase -= TWO_PI if @phase >= TWO_PI

      # 2. Clean carrier (pitch reference)
      carrier = sin(@phase)

      # 3. Energy tracker (slow, stable - tracks amplitude)
      @energy = @damp * @energy + (1.0 - @damp) * (carrier * carrier)

      # 4. Recursive PM state (spectral motion only, never feeds back to phase)
      @fb_state = @damp * @fb_state + (1.0 - @damp) * carrier

      # 5. Effective curvature (with optional amplitude evolution)
      # When evolve > 0, louder = more curvature effect
      k = @curvature * (1.0 + @evolve * @energy * 4.0)

      # 6. Spectral curvature warp
      # Each harmonic n gets phase offset proportional to n² (Duffing-like stiffness)
      # This bends the harmonic geometry without moving the fundamental
      #
      # k > 0: partials spread upward (hardening, brass-like)
      # k < 0: partials collapse inward (softening)
      #
      # The fb_state adds temporal memory/motion to the partials

      fb = @beta * @fb_state

      warp = carrier +                                           # Fundamental (stable)
             @h2_amp * k * sin(2.0 * @phase + 1.0 * fb) +        # 2nd harmonic
             @h3_amp * k * sin(3.0 * @phase + 2.0 * fb) +        # 3rd harmonic
             @h4_amp * k * sin(4.0 * @phase + 3.0 * fb) +        # 4th harmonic
             @h5_amp * k * sin(5.0 * @phase + 4.0 * fb)          # 5th harmonic

      # 7. Soft clip to prevent overflow at extreme settings
      DSP.fast_tanh(warp)
    end

    def srate=(rate)
      super
      self.freq = @freq
    end
  end


  # ============================================================================
  # CURVED RPM OSCILLATOR (Extended) - More Harmonics + Quadratic Spacing
  # ============================================================================
  #
  # Extended version with:
  # - More harmonics (up to 8th)
  # - Quadratic phase offset scaling (true Duffing stiffness model)
  # - Separate odd/even harmonic control
  # - Formant-like resonance emphasis
  #
  class CurvedRPMOscillatorX < Oscillator
    include DSP::Math

    # Primary parameters
    param_accessor :curvature,    :default => 0.0,   :range => (-1.0..1.0)
    param_accessor :beta,         :default => 0.3,   :range => (0.0..1.0)
    param_accessor :evolve,       :default => 0.0,   :range => (0.0..1.0)
    param_accessor :damp,         :default => 0.99,  :range => (0.95..0.999)

    # Harmonic structure
    param_accessor :odd_amt,      :default => 1.0,   :range => (0.0..2.0)   # Odd harmonic emphasis
    param_accessor :even_amt,     :default => 0.5,   :range => (0.0..2.0)   # Even harmonic emphasis
    param_accessor :rolloff,      :default => 0.7,   :range => (0.3..1.0)   # High harmonic rolloff
    param_accessor :num_harmonics,:default => 6,     :range => (2..8)       # Number of harmonics

    # Quadratic vs linear spacing
    param_accessor :quad_amt,     :default => 1.0,   :range => (0.0..2.0)   # Quadratic phase scaling

    def initialize(freq = DEFAULT_FREQ)
      @curvature = 0.0
      @beta = 0.3
      @evolve = 0.0
      @damp = 0.99
      @odd_amt = 1.0
      @even_amt = 0.5
      @rolloff = 0.7
      @num_harmonics = 6
      @quad_amt = 1.0
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @omega = TWO_PI * @freq * inv_srate
    end

    def clear!
      @phase = 0.0
      @energy = 0.0
      @fb_state = 0.0
    end

    def tick
      # 1. Advance fundamental (stable)
      @phase += @omega
      @phase -= TWO_PI if @phase >= TWO_PI

      # 2. Clean carrier
      carrier = sin(@phase)

      # 3. Energy tracking
      @energy = @damp * @energy + (1.0 - @damp) * (carrier * carrier)

      # 4. Recursive state
      @fb_state = @damp * @fb_state + (1.0 - @damp) * carrier

      # 5. Effective curvature with evolution
      k = @curvature * (1.0 + @evolve * @energy * 4.0)

      # 6. Build harmonic sum with quadratic Duffing-like phase offsets
      fb = @beta * @fb_state
      warp = carrier  # Start with fundamental

      n_harm = @num_harmonics.to_i.clamp(2, 8)

      (2..n_harm).each do |n|
        # Amplitude: odd/even weighting with rolloff
        is_odd = (n % 2 == 1)
        base_amp = is_odd ? @odd_amt : @even_amt
        amp = base_amp * (@rolloff ** (n - 1)) / n.to_f

        # Phase offset: quadratic scaling for Duffing-like stiffness
        # n² scaling makes higher harmonics move more
        phase_offset = (n - 1) * fb * (1.0 + @quad_amt * (n - 1) * 0.1)

        warp += k * amp * sin(n * @phase + phase_offset)
      end

      # 7. Soft clip
      DSP.fast_tanh(warp)
    end

    def srate=(rate)
      super
      self.freq = @freq
    end
  end


  # ============================================================================
  # INHARMONIC RPM OSCILLATOR - Allpass Dispersion for True Inharmonicity
  # ============================================================================
  #
  # Uses an allpass filter in the feedback path to create TRUE inharmonicity,
  # not just quasi-inharmonic motion like the CurvedRPM.
  #
  # Why allpass works:
  #   - Allpass has flat magnitude but frequency-dependent phase delay
  #   - In feedback loop, each harmonic sees different effective delay
  #   - This causes partials to detune from integer ratios
  #
  # This is the same principle used in:
  #   - Karplus-Strong dispersion filters
  #   - Stiff string / piano models
  #   - Digital waveguide inharmonicity
  #
  # dispersion > 0: stretched partials (stiff bars, bells, piano upper register)
  # dispersion < 0: compressed partials (membranes, thick strings)
  # dispersion = 0: harmonic (standard RPM)
  #
  class InharmonicRPM < Oscillator
    include DSP::Math

    # Primary parameters
    param_accessor :beta,       :default => 1.0,   :range => (0.0..3.0)    # PM depth
    param_accessor :dispersion, :default => 0.0,   :range => (-0.99..0.99) # Inharmonicity
    param_accessor :evolve,     :default => 0.0,   :range => (0.0..1.0)    # Amplitude→dispersion

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.0
      @dispersion = 0.0
      @evolve = 0.0
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @omega = TWO_PI * @freq * inv_srate
    end

    def clear!
      @phase = 0.0
      @fb = 0.0
      @fb_prev = 0.0  # TPT: track previous feedback
      # One-pole allpass state
      @ap_x1 = 0.0
      @ap_y1 = 0.0
    end

    def tick
      # 1. Advance fundamental phase (LOCKED - never modulated)
      @phase += @omega
      @phase -= TWO_PI if @phase >= TWO_PI

      # 2. TPT feedback (trapezoidal average for ~zero-delay)
      fb_tpt = 0.5 * (@fb + @fb_prev)

      # 3. Effective dispersion (optionally amplitude-dependent)
      disp_eff = @dispersion * (1.0 + @evolve * fb_tpt.abs * 2.0)
      disp_eff = disp_eff.clamp(-0.99, 0.99)

      # 4. One-pole allpass filter on feedback path
      # y[n] = -a * x[n] + x[n-1] + a * y[n-1]
      # Phase delay increases with frequency when a > 0
      ap_out = -disp_eff * fb_tpt + @ap_x1 + disp_eff * @ap_y1
      @ap_x1 = fb_tpt
      @ap_y1 = ap_out

      # 5. Recursive PM using dispersed feedback
      y = sin(@phase + @beta * ap_out)

      # 6. Update feedback history (TPT)
      @fb_prev = @fb
      @fb = y
      y
    end

    def srate=(rate)
      super
      self.freq = @freq
    end
  end


  # ============================================================================
  # INHARMONIC RPM (Two-Pole) - Stronger Dispersion Control
  # ============================================================================
  #
  # Two cascaded allpass sections for more pronounced inharmonicity.
  # Also adds a second dispersion parameter for asymmetric stretching.
  #
  class InharmonicRPM2 < Oscillator
    include DSP::Math

    param_accessor :beta,        :default => 1.0,   :range => (0.0..3.0)
    param_accessor :dispersion,  :default => 0.0,   :range => (-0.99..0.99)  # First allpass
    param_accessor :dispersion2, :default => 0.0,   :range => (-0.99..0.99)  # Second allpass
    param_accessor :evolve,      :default => 0.0,   :range => (0.0..1.0)

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.0
      @dispersion = 0.0
      @dispersion2 = 0.0
      @evolve = 0.0
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @omega = TWO_PI * @freq * inv_srate
    end

    def clear!
      @phase = 0.0
      @fb = 0.0
      @fb_prev = 0.0  # TPT
      # Two allpass stages
      @ap1_x1 = 0.0
      @ap1_y1 = 0.0
      @ap2_x1 = 0.0
      @ap2_y1 = 0.0
    end

    def tick
      # 1. Fundamental phase (locked)
      @phase += @omega
      @phase -= TWO_PI if @phase >= TWO_PI

      # 2. TPT feedback
      fb_tpt = 0.5 * (@fb + @fb_prev)

      # 3. Amplitude-dependent dispersion
      fb_amp = fb_tpt.abs
      d1 = (@dispersion * (1.0 + @evolve * fb_amp * 2.0)).clamp(-0.99, 0.99)
      d2 = (@dispersion2 * (1.0 + @evolve * fb_amp * 2.0)).clamp(-0.99, 0.99)

      # 4. First allpass
      ap1 = -d1 * fb_tpt + @ap1_x1 + d1 * @ap1_y1
      @ap1_x1 = fb_tpt
      @ap1_y1 = ap1

      # 5. Second allpass (cascaded)
      ap2 = -d2 * ap1 + @ap2_x1 + d2 * @ap2_y1
      @ap2_x1 = ap1
      @ap2_y1 = ap2

      # 6. Recursive PM
      y = sin(@phase + @beta * ap2)

      # 7. Update TPT history
      @fb_prev = @fb
      @fb = y
      y
    end

    def srate=(rate)
      super
      self.freq = @freq
    end
  end


  # ============================================================================
  # INHARMONIC RPM (Multi-Stage) - Maximum Dispersion Control
  # ============================================================================
  #
  # Variable number of allpass stages for fine-grained inharmonicity control.
  # More stages = more pronounced partial stretching.
  #
  # Also includes:
  #   - Brightness control (one-pole lowpass on feedback)
  #   - Separate stretch parameter for piano-like behavior
  #
  class InharmonicRPMX < Oscillator
    include DSP::Math

    param_accessor :beta,       :default => 1.0,   :range => (0.0..4.0)
    param_accessor :dispersion, :default => 0.0,   :range => (-0.95..0.95)
    param_accessor :stages,     :default => 2,     :range => (1..6)        # Number of allpass stages
    param_accessor :stretch,    :default => 0.0,   :range => (-1.0..1.0)   # Additional stretch factor
    param_accessor :brightness, :default => 1.0,   :range => (0.1..1.0)    # Feedback lowpass (1.0 = bypass)
    param_accessor :evolve,     :default => 0.0,   :range => (0.0..1.0)

    MAX_STAGES = 6

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.0
      @dispersion = 0.0
      @stages = 2
      @stretch = 0.0
      @brightness = 1.0
      @evolve = 0.0
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @omega = TWO_PI * @freq * inv_srate
      # Brightness filter coefficient (higher freq = brighter)
      update_brightness_coeff
    end

    def brightness=(b)
      @brightness = b
      update_brightness_coeff
    end

    def clear!
      @phase = 0.0
      @fb = 0.0
      @fb_prev = 0.0  # TPT
      @lp_state = 0.0
      # Allpass states for up to MAX_STAGES
      @ap_x1 = Array.new(MAX_STAGES, 0.0)
      @ap_y1 = Array.new(MAX_STAGES, 0.0)
    end

    def tick
      # 1. Fundamental phase (locked)
      @phase += @omega
      @phase -= TWO_PI if @phase >= TWO_PI

      # 2. TPT feedback
      fb_tpt = 0.5 * (@fb + @fb_prev)

      # 3. Brightness lowpass on feedback (before allpass chain)
      @lp_state += @lp_alpha * (fb_tpt - @lp_state)
      filtered_fb = @lp_state

      # 4. Amplitude-dependent dispersion
      fb_amp = filtered_fb.abs
      base_disp = @dispersion + @stretch * 0.3
      d = (base_disp * (1.0 + @evolve * fb_amp * 3.0)).clamp(-0.95, 0.95)

      # 5. Cascade of allpass filters
      signal = filtered_fb
      n_stages = @stages.to_i.clamp(1, MAX_STAGES)

      n_stages.times do |i|
        # Each stage can have slightly different coefficient for richer dispersion
        stage_d = d * (1.0 + i * 0.05 * @stretch.abs)
        stage_d = stage_d.clamp(-0.95, 0.95)

        ap_out = -stage_d * signal + @ap_x1[i] + stage_d * @ap_y1[i]
        @ap_x1[i] = signal
        @ap_y1[i] = ap_out
        signal = ap_out
      end

      # 6. Recursive PM with dispersed feedback
      y = sin(@phase + @beta * signal)

      # 7. Update TPT history
      @fb_prev = @fb
      @fb = y
      y
    end

    def srate=(rate)
      super
      self.freq = @freq
      update_brightness_coeff
    end

    private

    def update_brightness_coeff
      # Map brightness 0.1-1.0 to cutoff roughly 500Hz - 20kHz
      cutoff = 500.0 + (@brightness ** 2) * 19500.0
      @lp_alpha = 1.0 - ::Math.exp(-TWO_PI * cutoff * inv_srate)
    end
  end


  # ============================================================================
  # INHARMONIC RPM with 2nd-Order Biquad Allpass (Pirkle-style)
  # ============================================================================
  #
  # Uses proper 2nd-order biquad allpass filters for more precise dispersion.
  # Based on Will Pirkle's kAPF2 implementation.
  #
  # Key differences from 1st-order:
  #   - 180° phase shift at center frequency (vs 90° for 1st-order)
  #   - Q parameter controls bandwidth of phase transition
  #   - More "localized" dispersion effect
  #   - Can target specific frequency regions
  #
  # Parameters:
  #   fc: Center frequency of the allpass (where phase = 180°)
  #   Q:  Controls bandwidth of phase transition (higher Q = narrower)
  #
  class InharmonicRPM2ndOrder < Oscillator
    include DSP::Math

    param_accessor :beta,       :default => 1.2,    :range => (0.0..3.0)
    param_accessor :apf_fc,     :default => 1000.0, :range => (100.0..8000.0)  # APF center freq
    param_accessor :apf_q,      :default => 0.7,    :range => (0.1..4.0)       # APF Q (bandwidth)
    param_accessor :dispersion, :default => 0.5,    :range => (0.0..1.0)       # Wet/dry of APF
    param_accessor :evolve,     :default => 0.0,    :range => (0.0..1.0)

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.2
      @apf_fc = 1000.0
      @apf_q = 0.7
      @dispersion = 0.5
      @evolve = 0.0
      super freq
      clear!
      update_apf_coeffs
    end

    def freq=(f)
      @freq = f.to_f
      @omega = TWO_PI * @freq * inv_srate
    end

    def apf_fc=(f)
      @apf_fc = f.to_f
      update_apf_coeffs
    end

    def apf_q=(q)
      @apf_q = q.to_f
      update_apf_coeffs
    end

    def clear!
      @phase = 0.0
      @fb = 0.0
      @fb_prev = 0.0  # TPT
      # Biquad state (Direct Form II Transposed)
      @z1 = 0.0
      @z2 = 0.0
    end

    def tick
      # 1. Fundamental phase (locked)
      @phase += @omega
      @phase -= TWO_PI if @phase >= TWO_PI

      # 2. TPT feedback
      fb_tpt = 0.5 * (@fb + @fb_prev)

      # 3. Effective dispersion (optionally amplitude-dependent)
      disp = @dispersion * (1.0 + @evolve * fb_tpt.abs * 2.0)
      disp = disp.clamp(0.0, 1.0)

      # 4. 2nd-order biquad allpass (Direct Form II Transposed)
      # y[n] = a0*x[n] + a1*x[n-1] + a2*x[n-2] - b1*y[n-1] - b2*y[n-2]
      xn = fb_tpt
      yn = @a0 * xn + @z1
      @z1 = @a1 * xn - @b1 * yn + @z2
      @z2 = @a2 * xn - @b2 * yn

      # 5. Mix dry/wet based on dispersion
      apf_out = (1.0 - disp) * fb_tpt + disp * yn

      # 6. Recursive PM
      y = sin(@phase + @beta * apf_out)

      # 7. Update TPT history
      @fb_prev = @fb
      @fb = y
      y
    end

    def srate=(rate)
      super
      self.freq = @freq
      update_apf_coeffs
    end

    private

    def update_apf_coeffs
      # Pirkle's kAPF2 formula
      theta_c = TWO_PI * @apf_fc * inv_srate
      bw = @apf_fc / @apf_q
      arg_tan = PI * bw * inv_srate
      arg_tan = 0.95 * PI / 2.0 if arg_tan >= 0.95 * PI / 2.0

      alpha_num = ::Math.tan(arg_tan) - 1.0
      alpha_den = ::Math.tan(arg_tan) + 1.0
      alpha = alpha_num / alpha_den
      beta_coef = -::Math.cos(theta_c)

      @a0 = -alpha
      @a1 = beta_coef * (1.0 - alpha)
      @a2 = 1.0
      @b1 = beta_coef * (1.0 - alpha)
      @b2 = -alpha
    end
  end


  # ============================================================================
  # INHARMONIC RPM with Multiple 2nd-Order APFs
  # ============================================================================
  #
  # Cascade of 2nd-order biquad allpass filters at different frequencies.
  # This creates more complex, frequency-dependent dispersion patterns.
  #
  # Each APF stage can be tuned to target different harmonic regions,
  # creating selective inharmonicity (e.g., only affect upper partials).
  #
  class InharmonicRPMBiquad < Oscillator
    include DSP::Math

    param_accessor :beta,        :default => 1.2,   :range => (0.0..3.0)
    param_accessor :dispersion,  :default => 0.5,   :range => (0.0..1.0)

    # APF 1: Low frequency region
    param_accessor :apf1_fc,     :default => 500.0, :range => (50.0..2000.0)
    param_accessor :apf1_q,      :default => 0.5,   :range => (0.1..2.0)
    param_accessor :apf1_amt,    :default => 0.5,   :range => (0.0..1.0)

    # APF 2: Mid frequency region
    param_accessor :apf2_fc,     :default => 2000.0,:range => (200.0..6000.0)
    param_accessor :apf2_q,      :default => 0.7,   :range => (0.1..2.0)
    param_accessor :apf2_amt,    :default => 0.5,   :range => (0.0..1.0)

    # APF 3: High frequency region
    param_accessor :apf3_fc,     :default => 5000.0,:range => (500.0..12000.0)
    param_accessor :apf3_q,      :default => 0.8,   :range => (0.1..2.0)
    param_accessor :apf3_amt,    :default => 0.3,   :range => (0.0..1.0)

    param_accessor :evolve,      :default => 0.0,   :range => (0.0..1.0)

    def initialize(freq = DEFAULT_FREQ)
      @beta = 1.2
      @dispersion = 0.5
      @apf1_fc = 500.0
      @apf1_q = 0.5
      @apf1_amt = 0.5
      @apf2_fc = 2000.0
      @apf2_q = 0.7
      @apf2_amt = 0.5
      @apf3_fc = 5000.0
      @apf3_q = 0.8
      @apf3_amt = 0.3
      @evolve = 0.0
      super freq
      clear!
      update_all_coeffs
    end

    def freq=(f)
      @freq = f.to_f
      @omega = TWO_PI * @freq * inv_srate
    end

    def apf1_fc=(f); @apf1_fc = f; update_apf_coeffs(0); end
    def apf1_q=(q);  @apf1_q = q;  update_apf_coeffs(0); end
    def apf2_fc=(f); @apf2_fc = f; update_apf_coeffs(1); end
    def apf2_q=(q);  @apf2_q = q;  update_apf_coeffs(1); end
    def apf3_fc=(f); @apf3_fc = f; update_apf_coeffs(2); end
    def apf3_q=(q);  @apf3_q = q;  update_apf_coeffs(2); end

    def clear!
      @phase = 0.0
      @fb = 0.0
      @fb_prev = 0.0  # TPT
      @energy = 0.0
      # 3 biquad stages
      @z1 = [0.0, 0.0, 0.0]
      @z2 = [0.0, 0.0, 0.0]
      @coeffs = Array.new(3) { { a0: 0, a1: 0, a2: 0, b1: 0, b2: 0 } }
    end

    def tick
      # 1. Fundamental phase (locked)
      @phase += @omega
      @phase -= TWO_PI if @phase >= TWO_PI

      # 2. TPT feedback
      fb_tpt = 0.5 * (@fb + @fb_prev)

      # 3. Energy tracking for evolution
      @energy = 0.99 * @energy + 0.01 * (fb_tpt * fb_tpt)

      # 4. Process through 3 APF stages with individual amounts
      signal = fb_tpt
      amts = [@apf1_amt, @apf2_amt, @apf3_amt]
      evo_factor = 1.0 + @evolve * @energy * 3.0

      3.times do |i|
        # Biquad APF
        xn = signal
        c = @coeffs[i]
        yn = c[:a0] * xn + @z1[i]
        @z1[i] = c[:a1] * xn - c[:b1] * yn + @z2[i]
        @z2[i] = c[:a2] * xn - c[:b2] * yn

        # Mix with amount (evolved)
        amt = (amts[i] * evo_factor).clamp(0.0, 1.0)
        signal = (1.0 - amt) * signal + amt * yn
      end

      # 5. Apply overall dispersion
      apf_out = (1.0 - @dispersion) * fb_tpt + @dispersion * signal

      # 6. Recursive PM
      y = sin(@phase + @beta * apf_out)

      # 7. Update TPT history
      @fb_prev = @fb
      @fb = y
      y
    end

    def srate=(rate)
      super
      self.freq = @freq
      update_all_coeffs
    end

    private

    def update_all_coeffs
      update_apf_coeffs(0)
      update_apf_coeffs(1)
      update_apf_coeffs(2)
    end

    def update_apf_coeffs(idx)
      fc = [@apf1_fc, @apf2_fc, @apf3_fc][idx]
      q = [@apf1_q, @apf2_q, @apf3_q][idx]

      theta_c = TWO_PI * fc * inv_srate
      bw = fc / q
      arg_tan = PI * bw * inv_srate
      arg_tan = 0.95 * PI / 2.0 if arg_tan >= 0.95 * PI / 2.0

      alpha_num = ::Math.tan(arg_tan) - 1.0
      alpha_den = ::Math.tan(arg_tan) + 1.0
      alpha = alpha_num / alpha_den
      beta_coef = -::Math.cos(theta_c)

      @coeffs[idx] = {
        a0: -alpha,
        a1: beta_coef * (1.0 - alpha),
        a2: 1.0,
        b1: beta_coef * (1.0 - alpha),
        b2: -alpha
      }
    end
  end


  # ============================================================================
  # INHARMONIC + CURVED RPM (Combined)
  # ============================================================================
  #
  # Combines both approaches:
  #   - Allpass dispersion for TRUE inharmonicity (partial spacing)
  #   - Additive harmonics with curvature for spectral shape
  #
  # This gives you:
  #   - Controllable inharmonic series
  #   - Plus spectral curvature/evolution
  #   - Bell, bar, and membrane timbres with dynamic character
  #
  class InharmonicCurvedRPM < Oscillator
    include DSP::Math

    # Inharmonicity params
    param_accessor :dispersion, :default => 0.3,   :range => (-0.95..0.95)
    param_accessor :stages,     :default => 2,     :range => (1..4)

    # Curvature params
    param_accessor :curvature,  :default => 0.3,   :range => (-1.0..1.0)
    param_accessor :beta,       :default => 0.8,   :range => (0.0..2.0)

    # Common
    param_accessor :evolve,     :default => 0.0,   :range => (0.0..1.0)
    param_accessor :brightness, :default => 0.8,   :range => (0.1..1.0)

    # Harmonic amplitudes
    param_accessor :h2_amp,     :default => 0.3,   :range => (0.0..1.0)
    param_accessor :h3_amp,     :default => 0.2,   :range => (0.0..1.0)
    param_accessor :h4_amp,     :default => 0.12,  :range => (0.0..1.0)

    MAX_STAGES = 4

    def initialize(freq = DEFAULT_FREQ)
      @dispersion = 0.3
      @stages = 2
      @curvature = 0.3
      @beta = 0.8
      @evolve = 0.0
      @brightness = 0.8
      @h2_amp = 0.3
      @h3_amp = 0.2
      @h4_amp = 0.12
      super freq
      clear!
    end

    def freq=(f)
      @freq = f.to_f
      @omega = TWO_PI * @freq * inv_srate
      update_brightness_coeff
    end

    def brightness=(b)
      @brightness = b
      update_brightness_coeff
    end

    def clear!
      @phase = 0.0
      @fb = 0.0
      @fb_prev = 0.0  # TPT
      @lp_state = 0.0
      @energy = 0.0
      @ap_x1 = Array.new(MAX_STAGES, 0.0)
      @ap_y1 = Array.new(MAX_STAGES, 0.0)
    end

    def tick
      # 1. Fundamental phase (locked)
      @phase += @omega
      @phase -= TWO_PI if @phase >= TWO_PI

      # 2. TPT feedback (trapezoidal average for ~zero-delay)
      fb_tpt = 0.5 * (@fb + @fb_prev)

      # 3. Energy tracking
      @energy = 0.99 * @energy + 0.01 * (fb_tpt * fb_tpt)

      # 4. Brightness lowpass
      @lp_state += @lp_alpha * (fb_tpt - @lp_state)
      filtered_fb = @lp_state

      # 5. Allpass dispersion chain
      d = (@dispersion * (1.0 + @evolve * @energy * 4.0)).clamp(-0.95, 0.95)
      signal = filtered_fb
      n_stages = @stages.to_i.clamp(1, MAX_STAGES)

      n_stages.times do |i|
        ap_out = -d * signal + @ap_x1[i] + d * @ap_y1[i]
        @ap_x1[i] = signal
        @ap_y1[i] = ap_out
        signal = ap_out
      end

      # 6. Effective curvature
      k = @curvature * (1.0 + @evolve * @energy * 3.0)

      # 7. Build output: fundamental + curved harmonics + dispersed PM
      carrier = sin(@phase + @beta * signal)

      # Add harmonics with curvature-based phase offsets
      fb_phase = @beta * signal * 0.5
      output = carrier +
               @h2_amp * k * sin(2.0 * @phase + 1.0 * fb_phase) +
               @h3_amp * k * sin(3.0 * @phase + 2.0 * fb_phase) +
               @h4_amp * k * sin(4.0 * @phase + 3.0 * fb_phase)

      # 8. Update TPT history
      y = DSP.fast_tanh(output)
      @fb_prev = @fb
      @fb = y
      y
    end

    def srate=(rate)
      super
      self.freq = @freq
      update_brightness_coeff
    end

    private

    def update_brightness_coeff
      cutoff = 500.0 + (@brightness ** 2) * 15000.0
      @lp_alpha = 1.0 - ::Math.exp(-TWO_PI * cutoff * inv_srate)
    end
  end

end
