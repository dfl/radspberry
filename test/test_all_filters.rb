require_relative '../lib/radspberry'
include DSP

puts "Testing all Butterworth filter types..."

# Test 1: Bandpass filter
puts "\n1. Testing ButterBP (Bandpass at 1kHz)..."
noise = Noise.new
bpf = ButterBP.new(1000, q: 0.7)
chain = noise >> bpf
chain.to_wav(2, filename: "test_butterbp_1khz.wav")
puts "   Saved: test_butterbp_1khz.wav (should only pass frequencies around 1kHz)"

# Test 2: Notch filter
puts "\n2. Testing ButterNotch (Notch at 1kHz)..."
noise = Noise.new
notch = ButterNotch.new(1000, q: 2.0)  # Higher Q for narrower notch
chain = noise >> notch
chain.to_wav(2, filename: "test_butternotch_1khz.wav")
puts "   Saved: test_butternotch_1khz.wav (should reject frequencies around 1kHz)"

# Test 3: Peak EQ boost
puts "\n3. Testing ButterPeak (Peak at 1kHz, +12dB boost)..."
noise = Noise.new
peak = ButterPeak.new(1000, q: 1.0, gain: 12.0)
chain = noise >> peak
chain.to_wav(2, filename: "test_butterpeak_boost.wav")
puts "   Saved: test_butterpeak_boost.wav (should boost frequencies around 1kHz)"

# Test 4: Peak EQ cut
puts "\n4. Testing ButterPeak (Peak at 1kHz, -12dB cut)..."
noise = Noise.new
peak = ButterPeak.new(1000, q: 1.0, gain: -12.0)
chain = noise >> peak
chain.to_wav(2, filename: "test_butterpeak_cut.wav")
puts "   Saved: test_butterpeak_cut.wav (should cut frequencies around 1kHz)"

# Test 5: Low shelf boost
puts "\n5. Testing ButterLowShelf (500Hz, +12dB boost)..."
noise = Noise.new
lowshelf = ButterLowShelf.new(500, gain: 12.0)
chain = noise >> lowshelf
chain.to_wav(2, filename: "test_butterlowshelf_boost.wav")
puts "   Saved: test_butterlowshelf_boost.wav (should boost low frequencies)"

# Test 6: Low shelf cut
puts "\n6. Testing ButterLowShelf (500Hz, -12dB cut)..."
noise = Noise.new
lowshelf = ButterLowShelf.new(500, gain: -12.0)
chain = noise >> lowshelf
chain.to_wav(2, filename: "test_butterlowshelf_cut.wav")
puts "   Saved: test_butterlowshelf_cut.wav (should cut low frequencies)"

# Test 7: High shelf boost
puts "\n7. Testing ButterHighShelf (2kHz, +12dB boost)..."
noise = Noise.new
highshelf = ButterHighShelf.new(2000, gain: 12.0)
chain = noise >> highshelf
chain.to_wav(2, filename: "test_butterhighshelf_boost.wav")
puts "   Saved: test_butterhighshelf_boost.wav (should boost high frequencies)"

# Test 8: High shelf cut
puts "\n8. Testing ButterHighShelf (2kHz, -12dB cut)..."
noise = Noise.new
highshelf = ButterHighShelf.new(2000, gain: -12.0)
chain = noise >> highshelf
chain.to_wav(2, filename: "test_butterhighshelf_cut.wav")
puts "   Saved: test_butterhighshelf_cut.wav (should cut high frequencies)"

# Test 9: Sweep test - bandpass with varying frequency
puts "\n9. Testing ButterBP sweep (100Hz to 4kHz)..."
noise = Noise.new
bpf_sweep = ButterBP.new(100, q: 1.0)
chain = noise >> bpf_sweep
chain.to_wav(4, filename: "test_butterbp_sweep.wav") do |synth, progress|
  bpf_sweep.freq = 100 + progress * 3900  # 100Hz to 4kHz
end
puts "   Saved: test_butterbp_sweep.wav (bandpass sweep)"

# Test 10: Sweep test - peak gain sweep
puts "\n10. Testing ButterPeak gain sweep (1kHz, -12dB to +12dB)..."
osc = Phasor.new(1000)
peak_sweep = ButterPeak.new(1000, q: 1.0, gain: -12.0)
chain = osc >> peak_sweep
chain.to_wav(4, filename: "test_butterpeak_gainsweep.wav") do |synth, progress|
  peak_sweep.gain = -12.0 + progress * 24.0  # -12dB to +12dB
end
puts "   Saved: test_butterpeak_gainsweep.wav (gain sweep from cut to boost)"

puts "\n✓ All filter tests complete!"
puts "\nImplemented filters:"
puts "  - ButterHP: High-pass filter"
puts "  - ButterLP: Low-pass filter"
puts "  - ButterBP: Band-pass filter"
puts "  - ButterNotch: Notch/band-reject filter"
puts "  - ButterPeak: Parametric peaking EQ (boost/cut)"
puts "  - ButterLowShelf: Low shelf EQ (boost/cut)"
puts "  - ButterHighShelf: High shelf EQ (boost/cut)"
