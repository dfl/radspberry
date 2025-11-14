require_relative '../lib/radspberry'
include DSP

q = 7

puts "\n=== Function Composition Examples ==="
osc1 = Phasor.new(110)
osc2 = Phasor.new(110 * 1.495)
hpf = ButterBP.new(100, q:)
filtered = (osc1 + osc2) >> hpf >> Speaker

puts "\n2. Changing filter frequency on composed chain"
puts "\nHighpass filter"

hpf.freq = osc1.freq
while hpf.freq < Base.sample_rate/2
  hpf.freq *= 2**(1/(12.0*3))
  sleep 0.01
end

lpf = ButterLP.new(hpf.freq, q:)
filtered = (osc1 + osc2) >> lpf >> Speaker
puts "\nLowpass filter"
while lpf.freq > osc1.freq
  lpf.freq *= 2**(-1/12.0)
  sleep 0.05
end


puts "\n3. Parallel composition with + operator"
puts "   Creating: (Phasor(220) + Phasor(333)) >> ButterHP >> Speaker"


puts "   Playing mixed oscillators..."
sleep 2

puts "\n4. Complex multi-stage processing"
puts "   Creating: SuperSaw >> ButterHP(80) >> ButterLP(1000) >> Speaker"

q = 100
saw = SuperSaw.new(110)
complex_chain = saw >> ButterHP.new(80, q:) >> ButterLP.new(1000) >> Speaker

puts "   Playing complex chain..."
saw.spread = 0.5
sleep 2

puts "   Increasing spread..."
saw.spread = 0.9
sleep 2

puts "\n5. Crossfade composition"
puts "   Creating: SuperSaw.crossfade(RpmNoise)"

source_a = SuperSaw.new(110)
source_b = RpmNoise.new

# New crossfade syntax
fader = source_a.crossfade(source_b, 0.0) >> Speaker

# Or use traditional XFader[]
# fader = XFader[source_a, source_b] >> Speaker

source_a.spread = 0.8
puts "   Crossfading from SuperSaw to RpmNoise..."

10.times do |i|
  fader.fade = i / 10.0
  puts "   Fade: #{fader.fade.round(2)}"
  sleep 0.5
end

puts "\n7. Three-way mix with processing"
puts "   (Phasor + SuperSaw + RpmNoise) >> ButterHP >> Speaker"

(Phasor.new(220) + SuperSaw.new(110) + RpmNoise.new) >>
  ButterHP.new(60, q: 0.5) >>
  Speaker

sleep 3

Speaker.mute
puts "\n=== Composition API Demo Complete ==="
