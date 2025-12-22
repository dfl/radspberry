require 'minitest/autorun'
require_relative '../lib/radspberry'

class DummyOsc < DSP::Oscillator
  attr_accessor :param
  def tick; 0.0; end
end

class TestVoiceModulation < Minitest::Test
  include DSP

  def test_oscillator_modulation

    # Create a voice with this oscillator
    v = Voice.new(
      osc: DummyOsc.new,
      filter_env: Env.perc(attack: 0.1, decay: 0.1),
      osc_base: 10.0,
      osc_mod: 50.0,
      osc_mod_target: :param
    )

    # Initial state
    v.osc.param = 0.0
    
    # Trigger envelope
    v.note_on(:c4)
    
    # Tick it
    v.tick
    
    # The envelope value should be > 0, so param should be > 10
    assert v.osc.param > 10.0
    assert v.osc.param <= 60.0 # base + mod
  end

  def test_sync_preset
    v = Voice.sync
    assert_equal :sync_ratio, v.osc_mod_target
    assert_equal 1.0, v.osc_base
    assert_equal 7.0, v.osc_mod
    assert_equal 4.0, v.filter_env.decay
    assert_equal v.filter_env, v.sync_env
    assert_equal v.filter_env, v.mod_env
    
    v.note_on(:e2)
    v.tick
    # Verify sync_ratio was updated on the DualRPMOscillator
    assert v.osc.sync_ratio > 1.0
  end
end
