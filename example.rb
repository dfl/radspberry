require 'radspberry'

puts "starting simple oscillator"
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
  chain.fade += 0.1
  sleep 0.5
end

puts "muting"
Speaker.mute
sleep 1
