require_relative '../lib/radspberry'
include DSP


# puts "\n=== Function Composition Examples ==="


q = 7
delta = 0.04

osc1 = SuperSaw.new(110)
osc = (Phasor.new(110*1.495)+ osc1 + RpmNoise.new*0.8) / 3

puts "\nHighpass filter sweep"
hpf = ButterHP.new(100, q:)
# filtered = osc >> hpf >> Speaker

# hpf.freq = osc1.freq
# while hpf.freq < Base.sample_rate/2
#   hpf.freq *= 2**(1/(12.0))
#   sleep delta
# end

puts "\nHighpass filter -- with ParamSmoother"
hpf.clear!
hpf.freq = osc1.freq
hpf = ParamSmoother.new(hpf, params: [:freq])
filtered = osc >> hpf >> Speaker
filtered.clear!

while hpf.freq < Base.sample_rate/2
  hpf.freq *= 2**(1/(12.0))
  sleep delta
end

# puts "\nLowpass filter"

lpf = ButterLP.new(hpf.freq, q:)
# # lpf = ParamSmoother.new(lpf, params: [:freq])

# filtered = osc >> lpf >> Speaker
# while lpf.freq > osc1.freq
#   lpf.freq *= 2**(-1/12.0)
#   sleep delta
# end

puts "\nLowpass filter -- with ParamSmoother"
lpf.clear!
lpf.freq = hpf.freq
lpf = ParamSmoother.new(lpf, params: [:freq])
filtered = osc >> lpf >> Speaker
while lpf.freq > osc1.freq
  lpf.freq *= 2**(-1/12.0)
  sleep delta
end



puts "\n3. Complex multi-stage processing"
saw = SuperSaw.new(110)
sub = SuperSaw.new(110/4.0) 
(saw + sub) / 2 >> Speaker

puts "   Increasing SuperSaw spread..."
saw.spread = 0
8.times do 
  saw.spread += 0.1
  # sub.spread += 0.1
  sleep 1.5
end

Speaker.mute
puts "\n=== Composition API Demo Complete ==="


# TODO portamento glide for oscillator
# Parameter groups, saw1+saw2 same freq