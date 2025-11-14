require_relative '../lib/radspberry'
include DSP

puts "Testing ButterLP and ButterHP filters..."

# Test 1: White noise through lowpass filter
puts "\n1. Creating lowpass filtered noise (1kHz cutoff)..."
noise = Noise.new
lpf = ButterLP.new(1000, q: 0.7)
chain = noise >> lpf
chain.to_wav(2, filename: "test_butterlp_1khz.wav")
puts "   Saved: test_butterlp_1khz.wav"

# Test 2: White noise through highpass filter
puts "\n2. Creating highpass filtered noise (1kHz cutoff)..."
noise2 = Noise.new
hpf = ButterHP.new(1000, q: 0.7)
chain2 = noise2 >> hpf
chain2.to_wav(2, filename: "test_butterhp_1khz.wav")
puts "   Saved: test_butterhp_1khz.wav"

# Test 3: Sweep test - lowpass with varying cutoff
puts "\n3. Creating lowpass sweep (100Hz to 4kHz)..."
noise3 = Noise.new
lpf_sweep = ButterLP.new(100, q: 0.7)
chain3 = noise3 >> lpf_sweep
chain3.to_wav(4, filename: "test_butterlp_sweep.wav") do |synth, progress|
  lpf_sweep.freq = 100 + progress * 3900  # 100Hz to 4kHz
end
puts "   Saved: test_butterlp_sweep.wav"

# Test 4: Sweep test - highpass with varying cutoff
puts "\n4. Creating highpass sweep (4kHz to 100Hz)..."
noise4 = Noise.new
hpf_sweep = ButterHP.new(4000, q: 0.7)
chain4 = noise4 >> hpf_sweep
chain4.to_wav(4, filename: "test_butterhp_sweep.wav") do |synth, progress|
  hpf_sweep.freq = 4000 - progress * 3900  # 4kHz to 100Hz
end
puts "   Saved: test_butterhp_sweep.wav"

# Test 5: Tone through lowpass (should hear tone cut off)
puts "\n5. Creating tone (440Hz) through lowpass sweep (2kHz to 200Hz)..."
osc = Phasor.new(440)
lpf_tone = ButterLP.new(2000, q: 0.7)
chain5 = osc >> lpf_tone
chain5.to_wav(4, filename: "test_butterlp_tone.wav") do |synth, progress|
  lpf_tone.freq = 2000 - progress * 1800  # 2kHz to 200Hz
end
puts "   Saved: test_butterlp_tone.wav"

puts "\n✓ All filter tests complete!"
puts "\nListen to the files to verify:"
puts "  - LP sweep should go from bright to dull"
puts "  - HP sweep should go from dull to bright"
puts "  - LP tone should fade out as cutoff goes below 440Hz"
