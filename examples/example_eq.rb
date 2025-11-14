require_relative '../lib/radspberry'
include DSP

puts "=== Filter/EQ Examples ==="

# Example 1: Simple bandpass filter
puts "\n1. Bandpass filter at 1kHz"
osc = Phasor.new(440)
bpf = ButterBP.new(1000, q: 2.0)
(osc >> bpf >> Speaker)
sleep 2

# Example 2: Notch filter to remove a specific frequency
puts "\n2. Notch filter removing 440Hz"
osc = Phasor.new(440)
notch = ButterNotch.new(440, q: 5.0)  # High Q for narrow notch
(osc >> notch >> Speaker)
sleep 2

# Example 3: Multi-band EQ chain
puts "\n3. Multi-band EQ chain"
puts "   - Cut lows (-6dB @ 200Hz)"
puts "   - Boost mids (+6dB @ 1kHz)"
puts "   - Boost highs (+3dB @ 4kHz)"

saw = SuperSaw.new(110)
saw.spread = 0.7

# Build EQ chain
low_shelf = ButterLowShelf.new(200, gain: -6.0)
peak = ButterPeak.new(1000, q: 1.0, gain: 6.0)
high_shelf = ButterHighShelf.new(4000, gain: 3.0)

# Chain the filters
eq_chain = saw >> low_shelf >> peak >> high_shelf >> Speaker

puts "   Playing with EQ..."
sleep 3

# Example 4: Sweeping peak EQ
puts "\n4. Sweeping parametric EQ (1kHz to 4kHz, +12dB)"

saw2 = SuperSaw.new(110)
saw2.spread = 0.8
sweep_peak = ButterPeak.new(1000, q: 2.0, gain: 12.0)

saw2 >> sweep_peak >> Speaker

puts "   Sweeping peak frequency..."
20.times do |i|
  sweep_peak.freq = 1000 + i * 150  # 1kHz to 4kHz
  sleep 0.2
end

# Example 5: Dynamic gain control on peak filter
puts "\n5. Sweeping peak gain (-12dB to +12dB at 1.5kHz)"

saw3 = SuperSaw.new(110)
saw3.spread = 0.6
gain_peak = ButterPeak.new(1500, q: 1.5, gain: -12.0)

saw3 >> gain_peak >> Speaker

puts "   Sweeping gain from cut to boost..."
24.times do |i|
  gain_peak.gain = -12.0 + i * 1.0  # -12dB to +12dB
  sleep 0.2
end

# Example 6: Telephone bandpass effect
puts "\n6. Telephone bandpass effect (300Hz - 3.4kHz)"

music = SuperSaw.new(220)
music.spread = 0.5

# Use two filters: HPF at 300Hz and LPF at 3.4kHz
hpf = ButterHP.new(300, q: 0.7)
lpf = ButterLP.new(3400, q: 0.7)

music >> hpf >> lpf >> Speaker

puts "   Playing telephone effect..."
sleep 3

puts "\nMuting..."
Speaker.mute
sleep 1

puts "\n✓ Filter/EQ examples complete!"
