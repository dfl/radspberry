require 'minitest/autorun'

require_relative "../lib/radspberry"

class TestRadspberry < Minitest::Test
  include DSP

  def test_composition_with_operators
    # Test >> operator creates GeneratorChain
    osc = Phasor.new(440)
    hpf = ButterHP.new(100, q: 0.7)
    chain = osc >> hpf

    assert_instance_of GeneratorChain, chain
    assert_respond_to chain, :tick
    assert_respond_to chain, :ticks

    # Test chaining multiple processors
    lpf = ZDLP.new
    chain2 = osc >> hpf >> lpf
    assert_instance_of GeneratorChain, chain2

    # Test + operator creates Mixer
    osc2 = Phasor.new(880)
    mixed = osc + osc2
    assert_instance_of Mixer, mixed

    # Test crossfade
    fader = osc.crossfade(osc2, 0.5)
    assert_instance_of XFader, fader
    assert_equal 0.5, fader.fade

    puts "✓ Composition operators work correctly"
  end

  def test_composition_to_speaker
    # Test >> Speaker syntax
    osc = Phasor.new(440)
    result = osc >> Speaker

    # Should return the oscillator for further chaining
    assert_equal osc, result

    puts "✓ Composition to Speaker works"
  end

  def test_complex_composition
    # Test complex signal chains
    osc1 = Phasor.new(220)
    osc2 = Phasor.new(440)

    # Mix two oscillators and process
    hpf = ButterHP.new(100, q: 0.7)
    chain = (osc1 + osc2) >> hpf

    assert_respond_to chain, :tick
    assert_respond_to chain, :ticks

    puts "✓ Complex composition works"
  end

  def test_speaker
    Speaker[ Phasor.new ]
    sleep 1

    puts "changing frequency"
    Speaker.synth.freq /= 2
    sleep 1

    puts "changing frequency"
    Speaker.synth.freq /= 2
    sleep 1

    puts "starting crossfader (supersaw with rpmnoise)"
    chain = XFader[ o1=SuperSaw.new, o2=RpmNoise.new ]
    Speaker[ chain ]
    o1.spread  = 0.8
    chain.fade = 0
    sleep 5
    10.times do
      puts "crossfade to noise... (#{chain.fade += 0.1})"
      sleep 0.5
    end

    puts "muting"
    Speaker.mute
    sleep 1
  end  

end
