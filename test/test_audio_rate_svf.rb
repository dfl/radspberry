require_relative '../lib/radspberry'
include DSP

puts "Testing AudioRateSVF with audio-rate modulation..."

# Test 1: Basic filtering - compare to regular SVF
puts "\n1. Basic lowpass filtering..."
noise = Noise.new
svf = AudioRateSVF.new(freq: 1000.0, q: 2.0, kind: :low)
chain = noise >> svf
chain.to_wav(2, filename: "test_audiosvf_basic.wav")
puts "   Saved: test_audiosvf_basic.wav"

# Test 2: LFO modulation of cutoff (block rate for comparison)
puts "\n2. LFO modulation (block rate)..."
noise = Noise.new
svf = AudioRateSVF.new(freq: 1000.0, q: 4.0, kind: :low)
chain = noise >> svf
chain.to_wav(4, filename: "test_audiosvf_lfo.wav") do |synth, progress|
  # Sweep from 200Hz to 4000Hz with sine LFO at 2Hz
  lfo = Math.sin(progress * 4 * 2 * Math::PI) * 0.5 + 0.5
  svf.set_freq_fast(200 + lfo * 3800)
end
puts "   Saved: test_audiosvf_lfo.wav"

# Test 3: Audio-rate modulation (FM-style)
puts "\n3. Audio-rate FM modulation..."
class FMFilter < Generator
  def initialize
    @modulator = Phasor.new(50) # Modulation at 50Hz
    @svf = AudioRateSVF.new(freq: 1000.0, q: 8.0, kind: :low)
    @noise = Noise.new
  end

  def tick
    # Modulate filter frequency at audio rate
    mod = @modulator.tick
    mod_freq = 400 + mod * 3000  # 400Hz to 3400Hz

    input = @noise.tick
    @svf.tick_with_mod(input, mod_freq)
  end
end

fm = FMFilter.new
fm.to_wav(4, filename: "test_audiosvf_fm.wav")
puts "   Saved: test_audiosvf_fm.wav (filter FM at 50Hz)"

# Test 4: Faster audio-rate modulation
puts "\n4. Fast audio-rate modulation (200Hz mod)..."
class FastFMFilter < Generator
  def initialize
    @modulator = Phasor.new(200)
    @svf = AudioRateSVF.new(freq: 1000.0, q: 6.0, kind: :low)
    @noise = Noise.new
  end

  def tick
    mod = @modulator.tick
    mod_freq = 300 + mod * 2000
    @svf.tick_with_mod(@noise.tick, mod_freq)
  end
end

fast_fm = FastFMFilter.new
fast_fm.to_wav(4, filename: "test_audiosvf_fastfm.wav")
puts "   Saved: test_audiosvf_fastfm.wav (filter FM at 200Hz)"

# Test 5: Saturation/drive
puts "\n5. Saturation test (clean vs driven)..."
# Clean
noise = Noise.new
svf_clean = AudioRateSVF.new(freq: 800.0, q: 10.0, kind: :low, drive: 0.0)
chain = noise >> svf_clean
chain.to_wav(2, filename: "test_audiosvf_clean.wav")
puts "   Saved: test_audiosvf_clean.wav (no drive)"

# Driven
noise = Noise.new
svf_driven = AudioRateSVF.new(freq: 800.0, q: 10.0, kind: :low, drive: 12.0)
chain = noise >> svf_driven
chain.to_wav(2, filename: "test_audiosvf_driven.wav")
puts "   Saved: test_audiosvf_driven.wav (12dB drive)"

# Test 6: 4-pole mode
puts "\n6. 4-pole (24dB/oct) mode..."
noise = Noise.new
svf_4pole = AudioRateSVF.new(freq: 1000.0, q: 4.0, kind: :low)
svf_4pole.four_pole = true
chain = noise >> svf_4pole
chain.to_wav(2, filename: "test_audiosvf_4pole.wav")
puts "   Saved: test_audiosvf_4pole.wav"

# Sweep 4-pole with resonance (Q=4 for stability in 4-pole)
noise = Noise.new
svf_4pole = AudioRateSVF.new(freq: 100.0, q: 4.0, kind: :low)
svf_4pole.four_pole = true
chain = noise >> svf_4pole
chain.to_wav(4, filename: "test_audiosvf_4pole_sweep.wav") do |synth, progress|
  svf_4pole.set_freq_fast(100 + progress * 3900)
end
puts "   Saved: test_audiosvf_4pole_sweep.wav"

# Test 7: Different filter modes
puts "\n7. Filter mode comparison..."
[:low, :band, :high, :notch].each do |mode|
  noise = Noise.new
  svf = AudioRateSVF.new(freq: 1000.0, q: 4.0, kind: mode)
  chain = noise >> svf
  chain.to_wav(2, filename: "test_audiosvf_#{mode}.wav")
  puts "   Saved: test_audiosvf_#{mode}.wav"
end

# Test 8: Benchmark - fast vs accurate tan
puts "\n8. Benchmarking DSP.fast_tan accuracy..."
errors = []
[100, 500, 1000, 2000, 4000, 8000, 16000].each do |freq|
  x = freq / 44100.0
  accurate = Math.tan(Math::PI * x)
  fast = DSP.fast_tan(x)
  error_pct = ((fast - accurate) / accurate * 100).abs
  errors << error_pct
  puts "   #{freq}Hz: accurate=#{accurate.round(6)}, fast=#{fast.round(6)}, error=#{error_pct.round(4)}%"
end
puts "   Max error: #{errors.max.round(4)}%"

puts "\nAll AudioRateSVF tests complete!"
puts "\nKey features demonstrated:"
puts "  - Audio-rate frequency modulation via tick_with_mod()"
puts "  - Fast tan() approximation for efficient coefficient updates"
puts "  - Saturation/drive for analog character"
puts "  - 4-pole (24dB/oct) mode with inter-stage saturation"
puts "  - Multiple filter modes: low, band, high, notch"
