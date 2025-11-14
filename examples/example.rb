require_relative '../lib/radspberry'
include DSP

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
o1.spread  = 0
chain.fade = 0
puts "animating spread from 0 to 1"
10.times do
  o1.spread += 0.1
  sleep 0.5
end
puts "crossfading with noise from 0 to 1"
10.times do
  chain.fade += 0.1
  sleep 0.5
end

Speaker.mute
