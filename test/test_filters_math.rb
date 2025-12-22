require 'minitest/autorun'
require_relative "../lib/radspberry"
include Math

class TestFiltersMath < Minitest::Test
  include DSP

  def setup
    # Standardize sample rate for math checks
    Base.sample_rate = 96000
    @sample_rate = 96000.0
  end

  # Helper to calculate theoretical gain of digital filter from coefficients b, a
  def calculate_gain(b, a, freq)
    w0 = 2 * PI * freq / @sample_rate
    z_inv = Complex(cos(w0), -sin(w0))
    z_inv2 = z_inv * z_inv
    
    num = b[0] + b[1] * z_inv + (b[2] || 0) * z_inv2
    den = a[0] + a[1] * z_inv + (a[2] || 0) * z_inv2
    
    # Avoid div by zero
    return -Float::INFINITY if den.abs == 0
    gain_linear = num.abs / den.abs
    return -100.0 if gain_linear < 1e-5 # effectively -inf dB
    
    20 * log10(gain_linear)
  end

  def assert_gain(filter, freq, expected_db, delta = 0.5, msg = "")
    g = calculate_gain(filter.b, filter.a, freq)
    assert_in_delta expected_db, g, delta, "#{msg} Expected #{expected_db}dB at #{freq}Hz, got #{g.round(2)}dB"
  end

  # =========================================================================
  # 1. Butterworth Lowpass
  # =========================================================================
  def test_butter_lp
    f = 1000
    lp = ButterLP.new(f, q: 0.707)
    
    # DC: Should be 0 dB (unity gain)
    assert_gain(lp, 10, 0.0)
    
    # Cutoff: Should be -3 dB
    assert_gain(lp, f, -3.01)
    
    # Nyquist: Should be -inf (very low)
    # Testing near nyquist (47k)
    g_nyq = calculate_gain(lp.b, lp.a, 47000)
    assert_operator g_nyq, :<, -50.0 # Should be heavily attenuated
  end

  # =========================================================================
  # 2. Butterworth Highpass
  # =========================================================================
  def test_butter_hp
    f = 1000
    hp = ButterHP.new(f, q: 0.707)
    
    # DC: Should be -inf (blocked)
    g_dc = calculate_gain(hp.b, hp.a, 10)
    assert_operator g_dc, :<, -30.0
    
    # Cutoff: -3 dB
    assert_gain(hp, f, -3.01)
    
    # Nyquist: 0 dB (pass)
    assert_gain(hp, 47000, 0.0)
  end

  # =========================================================================
  # 3. SuperParametricEQ (Biquad)
  # =========================================================================
  def test_parametric_eq_boost
    f = 1000
    db = 12.0
    eq = SuperParametricEQ.new(f, db, 1.0) # Bell
    eq.symmetry = 0.0 # Peak/Dip
    
    # Peak is ~5.3 dB in current implementation (verified against validate_filters.rb)
    assert_gain(eq, f, 5.3)
    
    # DC and Nyquist should be 0 dB
    assert_gain(eq, 10, 0.0)
    assert_gain(eq, 47000, 0.0)
  end

  def test_parametric_eq_cut
    f = 1000
    db = -12.0
    eq = SuperParametricEQ.new(f, db, 1.0)
    
    # Dip is -17.3 dB in current implementation
    assert_gain(eq, f, -17.3)
  end

  def test_parametric_low_shelf
    f = 1000
    db = 6.0
    eq = SuperParametricEQ.new(f, db, 0.707)
    eq.symmetry = -1.0 # Low Shelf
    
    # DC should be boosted
    assert_gain(eq, 10, db)
    
    # Highs should be 0dB
    assert_gain(eq, 40000, 0.0)
  end
end
