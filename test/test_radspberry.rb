require "test/unit"
require "radspberry"

class TestRadspberry < Test::Unit::TestCase
  include DSP

  # def test_phasor
  #   p = Phasor.new
  #   assert_equal 0.0, p.tick
  # end
  
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
