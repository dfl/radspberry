require_relative '../lib/radspberry'
include DSP

puts "=== Filter Resonance Demo ==="
puts "Demonstrating Q parameter (resonance) on bandpass filter"

# Example 1: Low Q (gentle filtering)
puts "\n1. Low Q (Q=1.0) - gentle bandpass"
saw = SuperSaw.new(110, oversample: true)
saw.spread = 0.8
bpf = ButterBP.new(500, q: 1.0)
saw >> bpf >> Speaker
sleep 3

# Example 2: Medium Q (musical resonance)
puts "\n2. Medium Q (Q=10.0) - musical resonance"
saw2 = SuperSaw.new(110, oversample: true)
saw2.spread = 0.8
bpf2 = ButterBP.new(500, q: 10.0)
saw2 >> bpf2 >> Speaker
sleep 3

# Example 3: High Q (strong resonance)
puts "\n3. High Q (Q=30.0) - strong resonance"
saw3 = SuperSaw.new(110, oversample: true)
saw3.spread = 0.8
bpf3 = ButterBP.new(500, q: 30.0)
saw3 >> bpf3 >> Speaker
sleep 3

# Example 4: The 'resonance' parameter (0.0 to 1.0)
puts "\n4. Using 'resonance' (0.0 to 1.0 mapping)"
puts "   resonance = 0.0 maps to Q = 0.707 (No resonance)"
puts "   resonance = 1.0 maps to Q = 25.0  (Musical peak)"
saw4 = SuperSaw.new(110, oversample: true)
bpf4 = ButterBP.new(800)
saw4 >> bpf4 >> Speaker

puts "   Sweeping resonance from 0.0 to 1.0..."
40.times do |i|
  res = i / 40.0
  bpf4.resonance = res
  if i % 10 == 0
    q_val = 1.0 / bpf4.instance_variable_get(:@inv_q)
    puts "   resonance = #{res.round(2)} => Q = #{q_val.round(2)}"
  end
  sleep 0.1
end
sleep 0.5

# Example 5: High Q (Manual control)
puts "\n5. Manual Q control (Q=100.0) - extreme resonance"
saw5 = SuperSaw.new(110, oversample: true)
bpf5 = ButterBP.new(500, q: 100.0)
saw5 >> bpf5 >> Speaker
sleep 3.0

# Example 6: Resonant frequency sweep
puts "\n6. Resonant filter sweep (resonance=0.8, freq 200Hz to 2kHz)"
saw6 = SuperSaw.new(110, oversample: true)
bpf6 = ButterBP.new(200)
bpf6.resonance = 0.8
saw6 >> bpf6 >> Speaker

puts "   Sweeping frequency..."
50.times do |i|
  bpf6.freq = 200 + i * 36  # 200Hz to 2kHz
  sleep 0.1
end

puts "\nMuting..."
Speaker.mute
sleep 1

puts "\n✓ Resonance demo complete!"
puts "\nSummary:"
puts "  resonance = 0-1:  Easy musical control (Q: 0.7 to 25.0)"
puts "  q = 1-5:          Gentle filtering (subtle resonance)"
puts "  q = 5-20:         Musical resonance (noticable resonance)"
puts "  q = 20-100:       Strong resonance (ringing)"
puts "  q = 100+:         Extreme resonance (very loud, self-oscillation)"
puts "\nThe filter is stable at all Q values, but gets very loud above Q=100"
