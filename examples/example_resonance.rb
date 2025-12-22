require_relative '../lib/radspberry'
include DSP

puts "=== Filter Resonance Demo ==="
puts "Demonstrating Q parameter (resonance) on State Variable Filter"

# Example 1: Low Q (gentle filtering)
puts "\n1. Low Q (Q=0.707) - gentle bandpass"
(SuperSaw.new(110) >> SVF.new(kind: :band)[cutoff: 500, res: 0.707]).play(3)

# Example 2: Medium Q (musical resonance)
puts "\n2. Medium Q (Q=5.0) - musical resonance"
(SuperSaw.new(110) >> SVF.new(kind: :band)[cutoff: 500, res: 5.0]).play(3)

# Example 3: High Q (strong resonance)
puts "\n3. High Q (Q=20.0) - strong resonance"
(SuperSaw.new(110) >> SVF.new(kind: :band)[cutoff: 500, res: 20.0]).play(3)

# Example 4: Resonance sweep (0.5 to 40.0)
puts "\n4. Resonance sweep (Q 0.5 to 40.0)"

DSP::Synth.define :resonant_sweep do |freq: 110, cutoff: 800, res: 0.707|
  SuperSaw.new(freq) >> SVF.new(kind: :band)[cutoff: cutoff, res: res]
end

s4 = Synth[:resonant_sweep, freq: 110, cutoff: 800, res: 0.707]
Speaker.play(s4)

puts "   Sweeping resonance..."
40.times do |i|
  res = 0.5 + (i / 40.0) * 39.5
  s4.set(res: res)
  if i % 10 == 0
    puts "   Q = #{res.round(2)}"
  end
  sleep 0.1
end
sleep 0.5
Speaker.stop

# Example 5: Extreme Q
puts "\n5. Extreme Q (Q=100.0) - ringing"
(SuperSaw.new(110) >> SVF.new(kind: :band)[cutoff: 500, res: 100.0]).play(3.0)

# Example 6: Resonant frequency sweep
puts "\n6. Resonant frequency sweep (Q=15.0, 200Hz to 2kHz)"

s6 = Synth[:resonant_sweep, freq: 110, cutoff: 200, res: 15.0]
Speaker.play(s6)

puts "   Sweeping frequency..."
50.times do |i|
  cutoff = 200 + i * 36
  s6.set(cutoff: cutoff)
  sleep 0.1
end
Speaker.stop

puts "\n✓ Resonance demo complete!"
