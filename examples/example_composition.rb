require_relative '../lib/radspberry'
include DSP

q = 7
delta = 0.04

puts "\n=== Function Composition Examples ==="


osc1 = SuperSaw.new(110)
osc = (Phasor.new(110*1.495)+ osc1 + RpmNoise.new*0.8) / 3

# puts "\nHighpass filter sweep"
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
puts "   Creating: SuperSaw >> ButterHP(80) >> ButterLP(1000) >> Speaker"

saw1 = SuperSaw.new(110)
saw2 = SuperSaw.new(110*1.5) 

osc = ( saw1 + saw2 + RpmNoise.new) / 3

puts "   Increasing spread..."

5.times do 
  saw1.spread += 0.1
  saw2.spread += 0.1
end
sleep 2

Speaker.mute
puts "\n=== Composition API Demo Complete ==="
