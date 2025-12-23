require 'minitest/autorun'
require_relative "../lib/radspberry"

class TestApiLogic < Minitest::Test
  include DSP

  def setup
    # Reset clock to default for deterministic tests
    Clock.bpm = 120
    Clock.beats_per_bar = 4
  end

  # =========================================================================
  # 1. Note & Scale Logic
  # =========================================================================
  def test_frequency_conversions
    # Basic A4 = 440Hz
    assert_in_delta 440.0, Note.freq(:a4), 0.001
    assert_in_delta 440.0, DSP.to_freq(:a4), 0.001
    assert_in_delta 440.0, DSP.to_freq(midi: 69), 0.001
    
    # Test method injection on Symbol
    assert_in_delta 440.0, :a4.freq, 0.001
    assert_equal 69, :a4.midi
    
    # Octave shifts
    assert_in_delta 220.0, :a3.freq, 0.001
    assert_in_delta 880.0, :a5.freq, 0.001
  end

  def test_chord_and_scale_generation
    # C Major Triad
    assert_equal [:c4, :e4, :g4], :c4.major
    
    # A Minor Triad
    assert_equal [:a3, :c4, :e4], :a3.minor
    
    # Transposition
    assert_equal :g4, :c4 + 7
    assert_equal :c3, :c4.down(12)
    
    # Scale generation (just checking length and first/last for sanity)
    c_major = :c4.scale(:major)
    assert_equal 8, c_major.length
    assert_equal :c4, c_major.first
    assert_equal :c5, c_major.last
  end

  # =========================================================================
  # 2. Clock & Timing Logic
  # =========================================================================
  def test_clock_calculations
    Clock.bpm = 60
    assert_in_delta 1.0, 1.beat, 0.0001
    assert_in_delta 4.0, 1.bar, 0.0001
    
    Clock.bpm = 120
    assert_in_delta 0.5, 1.beat, 0.0001
    assert_in_delta 2.0, 1.bar, 0.0001
    
    # Ensure beats method alias works
    assert_in_delta 1.0, 2.beats, 0.0001
  end

  # =========================================================================
  # 3. Envelope Presets (Factory)
  # =========================================================================
  def test_envelope_factories
    # Env.adsr should return an AnalogEnvelope (sustain level capable)
    env = Env.adsr(attack: 0.1, sustain: 0.5)
    assert_instance_of AnalogEnvelope, env
    assert_in_delta 0.1, env.attack, 0.001
    assert_in_delta 0.5, env.sustain, 0.001
    
    # Env.perc should return something suited for percussion (usually AD)
    perc = Env.perc
    assert_kind_of AnalogADEnvelope, perc
    # Should have very short attack by default
    assert_operator perc.attack, :<, 0.1
    
    # Env.line
    line = Env.line(0, 100, 5)
    assert_instance_of Line, line
  end

  # =========================================================================
  # 4. Voice Configuration (No Audio Generation)
  # =========================================================================
  def test_voice_initialization
    # Default voice uses SuperSaw
    v = Voice.new
    assert_instance_of SuperSaw, v.osc
    assert_instance_of ButterLP, v.filter
    
    # Custom injection works (Classes)
    v2 = Voice.new(osc: RpmSquare)
    assert_instance_of RpmSquare, v2.osc
    
    # Custom injection works (Instances)
    my_filter = ButterHP.new(500)
    v3 = Voice.new(filter: my_filter)
    assert_equal my_filter, v3.filter
  end

  def test_voice_parameter_access
    v = Voice.new
    
    # Basic setters
    v.cutoff = 800
    assert_in_delta 800.0, v.cutoff, 0.001
    
    v.res = 0.8
    assert_in_delta 0.8, v.res, 0.001
    
    # Bulk setter
    v.set(cutoff: 1200, resonance: 0.2, attack: 0.1)
    
    assert_in_delta 1200.0, v.cutoff, 0.001
    assert_in_delta 0.2, v.res, 0.001
    assert_in_delta 0.1, v.attack, 0.001
  end

  def test_voice_state
    # Ensure presets return valid Voice instances
    acid = Voice.acid
    assert_instance_of Voice, acid
    assert_instance_of RpmSaw, acid.osc
    
    pad = Voice.pad
    assert_instance_of Voice, pad
    # Pad usually has slow attack
    assert_operator pad.attack, :>, 0.1
  end

  # =========================================================================
  # 5. Frequency Normalization (Logic from test/verify_normalization.rb)
  # =========================================================================
  def test_frequency_normalization
    # Integers should be treated as Hz, not MIDI
    objects = [
      SuperSaw.new,
      Phasor.new,
      DualRPMOscillator.new,
      NaiveRpmSync.new,
      Voice.new,
      ButterLP.new(1000),
      SVF.new,
      OnePoleZD.new
    ]

    objects.each do |obj|
      obj.freq = 110
      # Access @freq directly or via accessor
      actual = obj.instance_variable_get(:@freq) || obj.freq
      
      msg = "#{obj.class} treated '110' as #{actual}Hz (expected 110.0)"
      assert_in_delta 110.0, actual, 0.001, msg
    end
  end

  # =========================================================================
  # 6. Sonic Pi DSL Features
  # =========================================================================
  def test_rings
    r = ring(1, 2, 3)
    assert_instance_of DSP::DSL::Ring, r
    assert_equal 1, r[0]
    assert_equal 2, r[1]
    assert_equal 3, r[2]
    assert_equal 1, r[3], "Ring should wrap around"
    assert_equal 2, r[4], "Ring should wrap around"
    assert_equal 3, r[-1]
    assert_equal 2, r[-2]
  end

  def test_tick_and_look
    reset_tick
    assert_equal 0, tick
    assert_equal 1, tick
    assert_equal 1, look
    assert_equal 2, tick
    
    # Named ticks
    assert_equal 0, tick(:foo)
    assert_equal 0, tick(:bar)
    assert_equal 1, tick(:foo)
    assert_equal 3, tick # default still at 3
  end

  def test_ring_ticking
    r = ring(10, 20, 30)
    reset_tick(:r)
    assert_equal 10, r.tick(:r)
    assert_equal 20, r.tick(:r)
    assert_equal 30, r.tick(:r)
    assert_equal 10, r.tick(:r)
  end

  def test_spread
    # 3 pulses in 8 steps: [T, F, F, T, F, F, T, F]
    s = spread(3, 8)
    assert_equal [true, false, false, true, false, false, true, false], s.to_a
    
    # Empty/Full cases
    assert_equal [false, false], spread(0, 2).to_a
    assert_equal [true, true], spread(2, 2).to_a
  end

  def test_knit
    k = knit(:a, 2, :b, 1)
    assert_equal [:a, :a, :b], k.to_a
    assert_instance_of DSP::DSL::Ring, k
  end

  def test_pattern_helpers
    assert_respond_to self, :choose
    assert_respond_to self, :one_in
    assert_respond_to self, :dice
  end
end
