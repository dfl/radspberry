require_relative '../lib/radspberry'
include DSP

puts "=== Filter Resonance Demo ==="
puts "Demonstrating Q parameter (resonance) on bandpass filter"

# Example 1: Low Q (gentle filtering)
puts "\n1. Low Q (Q=1.0) - gentle bandpass"
saw = SuperSaw.new(110)
saw.spread = 0.8
bpf = ButterBP.new(500, q: 1.0)
saw >> bpf >> Speaker
sleep 3

# Example 2: Medium Q (musical resonance)
puts "\n2. Medium Q (Q=10.0) - musical resonance"
saw2 = SuperSaw.new(110)
saw2.spread = 0.8
bpf2 = ButterBP.new(500, q: 10.0)
saw2 >> bpf2 >> Speaker
sleep 3

# Example 3: High Q (strong resonance)
puts "\n3. High Q (Q=30.0) - strong resonance"
saw3 = SuperSaw.new(110)
saw3.spread = 0.8
bpf3 = ButterBP.new(500, q: 30.0)
saw3 >> bpf3 >> Speaker
sleep 3

# Example 4: Sweeping Q
puts "\n4. Sweeping Q from 1 to 50"
saw4 = SuperSaw.new(110)
saw4.spread = 0.6
bpf4 = ButterBP.new(800, q: 1.0)
saw4 >> bpf4 >> Speaker

puts "   Increasing resonance..."
40.times do |i|
  bpf4.q = 1.0 + i * 1.25  # Q from 1 to 50
  puts "   Q = #{bpf4.instance_variable_get(:@inv_q) ? (1.0 / bpf4.instance_variable_get(:@inv_q)).round(1) : '?'}" if i % 10 == 0
  sleep 0.15
end

# Example 5: Resonant sweep (filter frequency sweep with high Q)
puts "\n5. Resonant filter sweep (Q=25, freq 200Hz to 2kHz)"
saw5 = SuperSaw.new(110)
saw5.spread = 0.7
bpf5 = ButterBP.new(200, q: 25.0)
saw5 >> bpf5 >> Speaker

puts "   Sweeping frequency..."
50.times do |i|
  bpf5.freq = 200 + i * 36  # 200Hz to 2kHz
  sleep 0.1
end

puts "\nMuting..."
Speaker.mute
sleep 1

puts "\n✓ Resonance demo complete!"
puts "\nSummary:"
puts "  Q = 1-5:    Gentle filtering (subtle resonance)"
puts "  Q = 5-20:   Musical resonance (明显 resonance)"
puts "  Q = 20-100: Strong resonance (ringing)"
puts "  Q = 100+:   Extreme resonance (very loud, self-oscillation)"
puts "\nThe filter is stable at all Q values, but gets very loud above Q=100"
