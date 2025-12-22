# SuperParametricEQ - A unified parametric equalizer ported from dfl_SuperParametricEQ
# Ported from the superfreak codebase (Christensen, Berners & Abel, Orfanidis methods)

module DSP
  class SuperParametricEQ < Biquad
    attr_reader :frequency, :gain, :q, :symmetry, :resonance
    attr_reader :bandwidth_gain, :frequency_shift, :q_scaling, :match_nyquist
    attr_reader :preset

    # --- Preset Constants ---
    PRESETS = {
      pultec: { resonance: 0.7, q_scale: 0.6, bw_gain_ratio: 0.7, freq_shift: 0.5, q_scaling: 0.3, match_nyquist: true },
      neve: { resonance: 0.35, q_scale: 0.75, bw_gain_ratio: 0.6, freq_shift: 0.3, q_scaling: 0.4, match_nyquist: true },
      api: { resonance: 0.25, q_scale: 1.1, bw_gain_ratio: 0.45, freq_shift: 0.2, q_scaling: 0.5, match_nyquist: true },
      ssl: { resonance: 0.15, q_scale: 1.0, bw_gain_ratio: 0.5, freq_shift: 0.0, q_scaling: 0.2, match_nyquist: true },
      gml: { resonance: 0.0, q_scale: 1.0, bw_gain_ratio: 0.5, freq_shift: 0.0, q_scaling: 0.0, match_nyquist: true },
      massenburg: { resonance: 0.05, q_scale: 0.95, bw_gain_ratio: 0.5, freq_shift: 0.0, q_scaling: 0.0, match_nyquist: true },
      manley: { resonance: 0.5, q_scale: 0.5, bw_gain_ratio: 0.75, freq_shift: 0.6, q_scaling: 0.35, match_nyquist: true },
      baxandall: { resonance: 0.0, q_scale: 0.3, bw_gain_ratio: 0.8, freq_shift: 1.0, q_scaling: 0.2, match_nyquist: false },
      transparent: { resonance: 0.0, q_scale: 1.0, bw_gain_ratio: 0.5, freq_shift: 0.0, q_scaling: 0.0, match_nyquist: true },
      surgical: { resonance: 0.0, q_scale: 1.5, bw_gain_ratio: 0.35, freq_shift: 0.0, q_scaling: 0.0, match_nyquist: true },
      air: { resonance: 0.4, q_scale: 0.8, bw_gain_ratio: 0.55, freq_shift: 0.4, q_scaling: 0.25, match_nyquist: true },
      warm: { resonance: 0.3, q_scale: 0.7, bw_gain_ratio: 0.65, freq_shift: 0.3, q_scaling: 0.3, match_nyquist: false },
      dynamic: { resonance: 0.1, q_scale: 0.85, bw_gain_ratio: 0.7, freq_shift: 0.0, q_scaling: -0.2, match_nyquist: true },
      default: { resonance: 0.0, q_scale: 1.0, bw_gain_ratio: -1.0, freq_shift: 0.0, q_scaling: 0.0, match_nyquist: true }
    }

    def initialize(f = 1000.0, g = 0.0, q = 1.0)
      super([1.0, 0, 0], [1.0, 0, 0], interpolate: true)
      @frequency = f
      @gain = g
      @q = q
      @symmetry = 0.0      # -1 = lo shelf, 0 = bell, +1 = hi shelf
      @resonance = 0.0
      @bandwidth_gain = -1.0
      @frequency_shift = 0.0
      @q_scaling = 0.0
      @match_nyquist = true
      
      @preset = :default
      @q_scale = 1.0
      @bw_gain_ratio = -1.0
      
      recalc
    end

    def frequency=(f)
      @frequency = f.to_f
      recalc
    end

    def gain=(g)
      @gain = g.to_f
      recalc
    end

    def q=(q)
      @q = q.to_f
      recalc
    end

    def symmetry=(s)
      @symmetry = [[-1.0, s.to_f].max, 1.0].min
      recalc
    end

    def resonance=(r)
      @resonance = [0.0, r.to_f].max
      recalc
    end

    def bandwidth_gain=(bg)
      @bandwidth_gain = bg.to_f
      recalc
    end

    def match_nyquist=(bool)
      @match_nyquist = !!bool
      recalc
    end

    def frequency_shift=(fs)
      @frequency_shift = [[0.0, fs.to_f].max, 2.0].min
      recalc
    end

    def q_scaling=(qs)
      @q_scaling = [[-1.0, qs.to_f].max, 1.0].min
      recalc
    end

    def preset=(key)
      p = PRESETS[key.to_sym]
      return false unless p
      
      @preset = key.to_sym
      @resonance = p[:resonance]
      @q_scale = p[:q_scale]
      @bw_gain_ratio = p[:bw_gain_ratio]
      @frequency_shift = p[:freq_shift]
      @q_scaling = p[:q_scaling]
      @match_nyquist = p[:match_nyquist]
      
      recalc
      true
    end

    def recalc
      abs_gain = @gain.abs
      if abs_gain < 0.001
        update([1.0, 0.0, 0.0], [1.0, 0.0, 0.0])
        @nyquist_gain = 1.0
        return
      end

      # G = 10^(|G_dB|/20)
      lin_g = 10.0 ** (abs_gain / 20.0)

      # Bandwidth gain Gb
      if @bw_gain_ratio > 0.0
        gb = lin_g ** @bw_gain_ratio
      elsif @bandwidth_gain < 0.0
        gb = ::Math.sqrt(lin_g)
      else
        gb = 10.0 ** (@bandwidth_gain / 20.0)
        gb = 1.001 if gb <= 1.0
        gb = lin_g - 0.001 if gb >= lin_g
      end

      # DC and Nyquist gains
      # Correcting the Christensen/Orfanidis mapping:
      # DC (z=1) gain should be g0
      # Nyquist (z=-1) gain should be g1
      #
      # Symmetry map:
      # -1 = low shelf (DC=G, Nyq=1)
      #  0 = bell      (DC=1, Nyq=1)
      # +1 = high shelf (DC=1, Nyq=G)
      
      if @symmetry <= 0.0
        g0 = 1.0 + (lin_g - 1.0) * (-@symmetry)
        g1 = 1.0
      else
        g0 = 1.0
        g1 = 1.0 + (lin_g - 1.0) * @symmetry
      end

      # Peak gain at w0 is lin_g
      peak_g = lin_g

      abs_symm = @symmetry.abs
      if @match_nyquist && abs_symm < 0.5
        g0_sq = g0 * g0
        g_sq = lin_g * lin_g
        gb_sq = gb * gb
        if (g_sq - gb_sq).abs > 0.0001
          # Calculation for bell Nyquist matching
          g1_sq = g_sq * (g0_sq - gb_sq) / (g_sq - gb_sq)
          if g1_sq > 0.0
            g1_bell = ::Math.sqrt(g1_sq)
            bell_weight = 1.0 - 2.0 * abs_symm
            g1 = g1_bell * bell_weight + g1 * (1.0 - bell_weight)
          end
        end
      end

      @nyquist_gain = g1
      q_eff = @q * @q_scale

      if @q_scaling.abs > 0.001 && lin_g > 1.001
        q_eff *= (lin_g ** @q_scaling)
      end

      q_max = 25.0
      q_neutral = ::Math.sqrt(0.5)
      q_max_sh = 2.0

      if q_eff > q_neutral
        alpha = (::Math.log(q_max) - ::Math.log(q_max_sh)) / (::Math.log(q_max) - ::Math.log(q_neutral))
        exponent = 1.0 - alpha * abs_symm
        q_eff = q_neutral * (q_eff / q_neutral) ** exponent
      end

      q_eff = [0.1, q_eff, 50.0].sort[1]

      effective_freq = @frequency
      if @frequency_shift > 0.001 && @gain.abs > 0.1
        norm_gain = [@gain.abs / 12.0, 1.0].min
        oct_shift = @frequency_shift * norm_gain
        shift_dir = if @symmetry < -0.1
                      (@gain > 0) ? -1.0 : 1.0
                    elsif @symmetry > 0.1
                      (@gain > 0) ? 1.0 : -1.0
                    else
                      (@gain > 0) ? -0.5 : 0.5
                    end
        effective_freq = @frequency * (2.0 ** (oct_shift * shift_dir))
        effective_freq = [20.0, effective_freq, srate * 0.45].sort[1]
      end

      w0 = TWO_PI * effective_freq * inv_srate
      dw = w0 / q_eff

      g0_sq = g0 * g0
      g_sq = lin_g * lin_g
      gb_sq = gb * gb
      g1_sq = g1 * g1

      w_cap_0 = ::Math.tan(w0 * 0.5)
      w_cap_0_sq = w_cap_0 * w_cap_0

      f_val = (g_sq - gb_sq).abs; f_val = 0.0001 if f_val < 0.0001
      g00 = (g_sq - g0_sq).abs; g00 = 0.0001 if g00 < 0.0001
      g01 = (g_sq - g1_sq).abs
      g11 = (gb_sq - g1_sq).abs
      g00b = (g0_sq - gb_sq).abs
      
      epsilon_sq = g00b / f_val
      epsilon = ::Math.sqrt(epsilon_sq)

      resonance_scale = abs_symm
      q_p_mod = 1.0 + @resonance * resonance_scale

      # Orfanidis mapping:
      # DC gain (z=1) is controlled by the constant term
      # Nyquist gain (z=-1) is effectively the W0_sq limit
      # w0 gain is controlled by the Dw/2 term
      
      # Correcting the reverse-engineered C++:
      # We need H(z=1) = G0 and the high-freq limit to be G1?
      # Actually Orfanidis Eq 47/48 for Parametric:
      # b0 = G1*W0^2 + Gb*W0/Q + G0
      # ...
      
      a = epsilon * w_cap_0_sq + w_cap_0 / (q_eff * q_p_mod) + 1.0
      b = 2.0 * (epsilon * w_cap_0_sq - 1.0)
      c = epsilon * w_cap_0_sq - w_cap_0 / (q_eff * q_p_mod) + 1.0

      # d, e, f use the gain coefficients
      # H(z=1) = (d+e+f)/(a+b+c) should be g0 (Low freq gain)
      # H(z=-1) = (d-e+f)/(a-b+c) should be g1 (High freq gain)
      d = g0 * epsilon * w_cap_0_sq + gb * w_cap_0 / q_eff + g1
      e_coef = 2.0 * (g0 * epsilon * w_cap_0_sq - g1)
      f_coef = g0 * epsilon * w_cap_0_sq - gb * w_cap_0 / q_eff + g1

      b0 = d / a
      b1 = e_coef / a
      b2 = f_coef / a
      a1 = b / a
      a2 = c / a

      # Evaulate H(-1) for Orfanidis matching
      if @match_nyquist && abs_symm < 0.9
        num_nyq = b0 - b1 + b2
        den_nyq = 1.0 - a1 + a2 # Evaluation at z = -1
        h_nyq_current = (num_nyq / den_nyq).abs
        h_nyq_desired = g1
        corr_weight = 1.0 - abs_symm

        if h_nyq_current > 0.001 && (h_nyq_desired - h_nyq_current).abs > 0.001
          correction = (h_nyq_desired / h_nyq_current) ** (0.5 * corr_weight)
          hf_weight = 0.7
          b0 *= (1.0 + (correction - 1.0) * (1.0 - hf_weight))
          b2 *= correction * hf_weight + (1.0 - hf_weight)
        end
      end

      if @gain < 0.0
        # Invert transfer function: H_cut(z) = (G0*G1/G) / H_boost(z)
        inv_g = (g0 * g1) / peak_g
        norm = d # using d (original numerator b0*a) as new denominator 1.0
        
        nb0 = a * inv_g / norm
        nb1 = b * inv_g / norm
        nb2 = c * inv_g / norm
        na1 = e_coef / norm
        na2 = f_coef / norm
        
        update([nb0, nb1, nb2], [1.0, na1, na2])
        @nyquist_gain = 1.0 / @nyquist_gain if @nyquist_gain > 0.001
      else
        update([b0, b1, b2], [1.0, a1, a2])
      end
    end
  end
end
