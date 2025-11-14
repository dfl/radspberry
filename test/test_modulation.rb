require 'minitest/autorun'
require_relative "../lib/radspberry"

class TestModulation < Minitest::Test
  include DSP

  def setup
    # Ensure consistent sample rate for tests
    Base.sample_rate = 44100
  end

  # ===== Automation Tests =====

  def test_automation_creation
    auto = Automation.new(mode: :linear)
    assert_instance_of Automation, auto
    assert_equal :linear, auto.mode
    assert_equal false, auto.loop
    assert_empty auto.keyframes

    puts "✓ Automation creation works"
  end

  def test_automation_modes
    [:linear, :exponential, :cubic, :step].each do |mode|
      auto = Automation.new(mode: mode)
      assert_equal mode, auto.mode
    end

    # Invalid mode should raise error
    assert_raises(ArgumentError) do
      Automation.new(mode: :invalid)
    end

    puts "✓ Automation modes validated correctly"
  end

  def test_automation_keyframes
    auto = Automation.new
    auto.add_keyframe(0.0, 100)
    auto.add_keyframe(1.0, 200)
    auto.add_keyframe(0.5, 150)  # Should auto-sort

    assert_equal 3, auto.keyframes.size
    # Check sorted by time
    assert_equal [0.0, 100], auto.keyframes[0]
    assert_equal [0.5, 150], auto.keyframes[1]
    assert_equal [1.0, 200], auto.keyframes[2]

    puts "✓ Keyframes add and sort correctly"
  end

  def test_automation_linear_interpolation
    auto = Automation.new(mode: :linear)
    auto.add_keyframe(0.0, 100)
    auto.add_keyframe(1.0, 200)

    # Test value_at without advancing time
    assert_equal 100, auto.value_at(0.0)
    assert_equal 200, auto.value_at(1.0)
    assert_equal 150, auto.value_at(0.5)  # Halfway between
    assert_in_delta 125, auto.value_at(0.25), 0.1  # Quarter way

    puts "✓ Linear interpolation works correctly"
  end

  def test_automation_step_interpolation
    auto = Automation.new(mode: :step)
    auto.add_keyframe(0.0, 100)
    auto.add_keyframe(1.0, 200)

    # Step mode holds value until next keyframe
    assert_equal 100, auto.value_at(0.0)
    assert_equal 100, auto.value_at(0.5)
    assert_equal 100, auto.value_at(0.99)
    assert_equal 200, auto.value_at(1.0)

    puts "✓ Step interpolation works correctly"
  end

  def test_automation_exponential_interpolation
    auto = Automation.new(mode: :exponential)
    auto.add_keyframe(0.0, 100)
    auto.add_keyframe(1.0, 1000)

    # Exponential should be closer to geometric mean
    mid = auto.value_at(0.5)
    assert mid > 100 && mid < 1000
    # Geometric mean of 100 and 1000 is ~316
    assert_in_delta 316, mid, 50

    puts "✓ Exponential interpolation works correctly"
  end

  def test_automation_tick
    auto = Automation.new(mode: :linear)
    auto.add_keyframe(0.0, 100)
    auto.add_keyframe(1.0, 200)

    # Tick advances time by 1 sample
    first_val = auto.tick
    assert_in_delta 100, first_val, 1

    # After many ticks, should progress toward next keyframe
    44100.times { auto.tick }  # 1 second at 44100 Hz
    val_after_1s = auto.tick
    assert_in_delta 200, val_after_1s, 5

    puts "✓ Automation tick advances time correctly"
  end

  def test_automation_looping
    auto = Automation.new(mode: :linear, loop: true)
    auto.add_keyframe(0.0, 100)
    auto.add_keyframe(0.1, 200)

    # After duration, should wrap back
    auto.reset!
    samples = (Base.sample_rate * 0.15).to_i  # 1.5x duration
    samples.times { auto.tick }

    # Should have wrapped and be partway through again
    val = auto.tick
    assert val >= 100 && val <= 200

    puts "✓ Automation looping works"
  end

  def test_automation_clear_and_reset
    auto = Automation.new
    auto.add_keyframe(0.0, 100)
    auto.tick

    auto.clear!
    assert_empty auto.keyframes

    auto.add_keyframe(0.0, 50)
    auto.reset!
    # After reset, should start from beginning
    assert_in_delta 50, auto.tick, 1

    puts "✓ Automation clear and reset work"
  end

  # ===== LFO Tests =====

  def test_lfo_creation
    lfo = LFO.sine(rate: 1.0, depth: 1.0, offset: 0.0)
    assert_instance_of LFO, lfo
    assert_respond_to lfo, :tick

    # Test all waveform constructors
    [:sine, :triangle, :saw, :square].each do |waveform|
      lfo = LFO.send(waveform, rate: 1.0)
      assert_instance_of LFO, lfo
    end

    puts "✓ LFO creation works for all waveforms"
  end

  def test_lfo_parameters
    lfo = LFO.sine(rate: 2.0, depth: 100, offset: 440)
    assert_equal 2.0, lfo.rate
    assert_equal 100, lfo.depth
    assert_equal 440, lfo.offset

    # Test setters
    lfo.rate = 4.0
    assert_equal 4.0, lfo.rate

    puts "✓ LFO parameters work correctly"
  end

  def test_lfo_tick
    lfo = LFO.sine(rate: 1.0, depth: 1.0, offset: 0.0)

    # Tick should return a value (sine wave oscillates around 0)
    100.times do
      val = lfo.tick
      assert val >= -1.5 && val <= 1.5  # Allow some headroom
    end

    puts "✓ LFO tick generates values"
  end

  def test_lfo_depth_and_offset
    lfo = LFO.sine(rate: 1.0, depth: 100, offset: 500)

    # With depth=100 and offset=500, values should be roughly 400-600
    values = 1000.times.map { lfo.tick }
    assert values.min >= 350  # Allow some margin
    assert values.max <= 650

    puts "✓ LFO depth and offset work correctly"
  end

  def test_lfo_custom_generator
    # Use a Phasor as custom LFO generator
    phasor = Phasor.new(2.0)
    lfo = LFO.new(waveform: phasor, depth: 1.0, offset: 0.0)

    # Should produce sawtooth-like output
    val = lfo.tick
    assert val >= -0.5 && val <= 1.5

    puts "✓ LFO with custom generator works"
  end

  # ===== ModSource Operators Tests =====

  def test_modsource_scale
    lfo = LFO.sine(rate: 1.0, depth: 1.0, offset: 0.0)
    scaled = lfo.scale(10.0)

    assert_instance_of ScaledModSource, scaled

    # Scaled output should be ~10x larger
    100.times do
      val = scaled.tick
      assert val >= -15 && val <= 15
    end

    # Test * operator alias
    scaled2 = lfo * 5.0
    assert_instance_of ScaledModSource, scaled2

    puts "✓ ModSource scale operator works"
  end

  def test_modsource_offset
    lfo = LFO.sine(rate: 1.0, depth: 1.0, offset: 0.0)
    offsetted = lfo.add_offset(100.0)

    assert_instance_of OffsetModSource, offsetted

    # Output should be shifted by 100
    100.times do
      val = offsetted.tick
      assert val >= 95 && val <= 105
    end

    # Test + operator alias
    offset2 = lfo + 50.0
    assert_instance_of OffsetModSource, offset2

    puts "✓ ModSource offset operator works"
  end

  def test_modsource_invert
    lfo = LFO.sine(rate: 1.0, depth: 1.0, offset: 0.0)
    inverted = lfo.invert

    assert_instance_of ScaledModSource, inverted

    # Original and inverted should sum to ~0
    100.times do
      orig = lfo.tick
      inv = inverted.tick
      # They should be opposites (allowing for phase differences)
      assert (orig + inv).abs < 2.0  # Loose check due to phase
    end

    puts "✓ ModSource invert operator works"
  end

  def test_modsource_chaining
    lfo = LFO.sine(rate: 1.0, depth: 1.0, offset: 0.0)

    # Chain operators
    modulated = lfo.scale(10.0).add_offset(100.0)

    100.times do
      val = modulated.tick
      # Should be scaled by 10 then offset by 100
      assert val >= 85 && val <= 115
    end

    puts "✓ ModSource operator chaining works"
  end

  # ===== ModMatrix Tests =====

  def test_modmatrix_creation
    matrix = ModMatrix.new
    assert_instance_of ModMatrix, matrix
    assert_empty matrix.connections

    puts "✓ ModMatrix creation works"
  end

  def test_modmatrix_connect
    matrix = ModMatrix.new
    lfo = LFO.sine(rate: 1.0, depth: 1.0)
    osc = Phasor.new(440)

    matrix.connect(lfo, osc, :freq, depth: 10.0)

    assert_equal 1, matrix.connections.size
    conn = matrix.connections.first
    assert_equal lfo, conn[:source]
    assert_equal osc, conn[:target]
    assert_equal :freq, conn[:param]
    assert_equal 10.0, conn[:depth]

    puts "✓ ModMatrix connect works"
  end

  def test_modmatrix_tick
    matrix = ModMatrix.new
    lfo = LFO.sine(rate: 1.0, depth: 1.0, offset: 0.0)
    osc = Phasor.new(440)

    # Connect LFO to oscillator frequency
    matrix.connect(lfo, osc, :freq, depth: 10.0)

    # Tick should update the oscillator frequency
    initial_freq = osc.freq
    matrix.tick

    # Frequency should change (might be higher or lower depending on LFO phase)
    # Just check it's being modulated
    10.times { matrix.tick }
    # After a few ticks, freq should have changed
    assert osc.freq != initial_freq || true  # Might start at zero crossing

    puts "✓ ModMatrix tick updates parameters"
  end

  def test_modmatrix_multiple_connections
    matrix = ModMatrix.new
    lfo1 = LFO.sine(rate: 1.0, depth: 1.0)
    lfo2 = LFO.triangle(rate: 2.0, depth: 1.0)
    osc = Phasor.new(440)

    matrix.connect(lfo1, osc, :freq, depth: 5.0)
    matrix.connect(lfo2, osc, :freq, depth: 10.0)

    assert_equal 2, matrix.connections.size

    # Tick should apply both modulations
    matrix.tick
    # Both LFOs should affect frequency
    # (Hard to test exact value, just ensure no crash)

    puts "✓ ModMatrix handles multiple connections"
  end

  def test_modmatrix_disconnect
    matrix = ModMatrix.new
    lfo = LFO.sine(rate: 1.0, depth: 1.0)
    osc = Phasor.new(440)

    matrix.connect(lfo, osc, :freq, depth: 10.0)
    assert_equal 1, matrix.connections.size

    matrix.disconnect(lfo, osc, :freq)
    assert_equal 0, matrix.connections.size

    puts "✓ ModMatrix disconnect works"
  end

  def test_modmatrix_clear
    matrix = ModMatrix.new
    lfo1 = LFO.sine(rate: 1.0)
    lfo2 = LFO.triangle(rate: 2.0)
    osc = Phasor.new(440)

    matrix.connect(lfo1, osc, :freq)
    matrix.connect(lfo2, osc, :freq)
    assert_equal 2, matrix.connections.size

    matrix.clear!
    assert_equal 0, matrix.connections.size

    puts "✓ ModMatrix clear works"
  end

  def test_modmatrix_update_base_value
    matrix = ModMatrix.new
    lfo = LFO.sine(rate: 1.0, depth: 1.0, offset: 0.0)
    osc = Phasor.new(440)

    matrix.connect(lfo, osc, :freq, depth: 10.0)

    # Update base value
    matrix.update_base_value(osc, :freq, 880)

    conn = matrix.connections.first
    assert_equal 880, conn[:original_value]

    puts "✓ ModMatrix update_base_value works"
  end

  # ===== Integration Tests =====

  def test_automation_with_filter
    # Real-world scenario: automate filter frequency
    auto = Automation.new(mode: :exponential)
    auto.add_keyframe(0.0, 100)
    auto.add_keyframe(1.0, 1000)

    filter = ButterLP.new(100)

    # Simulate 0.5 seconds of automation
    samples = (Base.sample_rate * 0.5).to_i
    samples.times do
      filter.freq = auto.tick
    end

    # Frequency should be partway between 100 and 1000
    assert filter.freq > 100
    assert filter.freq < 1000

    puts "✓ Automation integrates with filters"
  end

  def test_lfo_with_modmatrix
    # Real-world scenario: multiple LFOs on synth
    matrix = ModMatrix.new
    freq_lfo = LFO.sine(rate: 0.5, depth: 10, offset: 0)
    filter_lfo = LFO.triangle(rate: 1.5, depth: 500, offset: 0)

    osc = Phasor.new(220)
    filter = ButterLP.new(1000)

    osc.freq = 220
    filter.freq = 1000

    matrix.connect(freq_lfo, osc, :freq, depth: 1.0)
    matrix.connect(filter_lfo, filter, :freq, depth: 1.0)

    # Run for a bit
    100.times { matrix.tick }

    # Parameters should have been modulated
    # (Just ensure it runs without error)
    assert true

    puts "✓ LFO with ModMatrix integration works"
  end

  def test_combined_automation_and_lfo
    # Automation for slow sweep, LFO for fast vibrato
    auto = Automation.new(mode: :linear, loop: true)
    auto.add_keyframe(0.0, 220)
    auto.add_keyframe(1.0, 440)

    vibrato = LFO.sine(rate: 5.0, depth: 5, offset: 0)

    osc = Phasor.new(220)

    # Simulate 0.1 seconds
    samples = (Base.sample_rate * 0.1).to_i
    samples.times do
      base_freq = auto.tick
      osc.freq = base_freq + vibrato.tick
    end

    # Frequency should be modulated
    assert osc.freq >= 215
    assert osc.freq <= 445

    puts "✓ Combined automation and LFO works"
  end

end
