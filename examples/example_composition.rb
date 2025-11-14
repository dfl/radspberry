require 'radspberry'
include DSP

puts "\n=== Function Composition Examples ==="
puts "\n1. Simple composition with >> operator"
puts "   Creating: Phasor >> Hpf >> Speaker"

# Traditional way:
# Speaker[GeneratorChain.new([Phasor.new(440), Hpf.new(100, 0.7)])]

# New composition way:
osc = Phasor.new(440)
filtered = osc >> Hpf.new(100, 0.7) >> Speaker

puts "   Playing filtered oscillator..."
sleep 2

puts "\n2. Changing frequency on composed chain"
osc.freq = 220
sleep 1

puts "\n3. Parallel composition with + operator"
puts "   Creating: (Phasor(220) + Phasor(440)) >> Hpf >> Speaker"

osc1 = Phasor.new(220)
osc2 = Phasor.new(440)
mixed = (osc1 + osc2) >> Hpf.new(80, 0.7) >> Speaker

puts "   Playing mixed oscillators..."
sleep 2

puts "\n4. Complex multi-stage processing"
puts "   Creating: SuperSaw >> Hpf(80) >> ZDLP >> Speaker"

saw = SuperSaw.new(110)
complex_chain = saw >> Hpf.new(80, 0.7) >> ZDLP.new >> Speaker

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

puts "\n6. Inline composition (no intermediate variables)"
puts "   Creating everything in one line"

Phasor.new(330) >> Hpf.new(100) >> Speaker

sleep 2

puts "\n7. Three-way mix with processing"
puts "   (Phasor + SuperSaw + RpmNoise) >> Hpf >> Speaker"

(Phasor.new(220) + SuperSaw.new(110) + RpmNoise.new) >>
  Hpf.new(60, 0.5) >>
  Speaker

sleep 3

puts "\nMuting..."
Speaker.mute
sleep 1

puts "\n=== Composition API Demo Complete ==="
