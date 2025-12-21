require_relative '../lib/radspberry'
include DSP

puts "Testing oversampling..."

# Test 1: Compare saturated filter with and without oversampling
puts "\n1. Saturated filter comparison (should reduce aliasing)..."

# Without oversampling
noise = Noise.new
svf = AudioRateSVF.new(freq: 2000.0, q: 4.0, kind: :low, drive: 18.0)
chain = noise >> svf
chain.to_wav(2, filename: "test_no_oversample.wav")
puts "   Saved: test_no_oversample.wav (no oversampling)"

# With 2x oversampling
noise = Noise.new
svf = AudioRateSVF.new(freq: 2000.0, q: 4.0, kind: :low, drive: 18.0)
oversampled = DSP.oversample(svf, factor: 2)
chain = noise >> oversampled
chain.to_wav(2, filename: "test_2x_oversample.wav")
puts "   Saved: test_2x_oversample.wav (2x oversampling)"

# With 4x oversampling
noise = Noise.new
svf = AudioRateSVF.new(freq: 2000.0, q: 4.0, kind: :low, drive: 18.0)
oversampled = DSP.oversample(svf, factor: 4)
chain = noise >> oversampled
chain.to_wav(2, filename: "test_4x_oversample.wav")
puts "   Saved: test_4x_oversample.wav (4x oversampling)"

# Test 2: Sawtooth through saturated filter (aliasing is more audible)
puts "\n2. Sawtooth through saturated filter..."

class Sawtooth < Generator
  def initialize(freq)
    @phase = 0.0
    @inc = freq * inv_srate
  end

  def tick
    @phase += @inc
    @phase -= 1.0 if @phase >= 1.0
    @phase * 2.0 - 1.0  # -1 to 1
  end
end

# Without oversampling
saw = Sawtooth.new(220)
svf = AudioRateSVF.new(freq: 3000.0, q: 8.0, kind: :low, drive: 24.0)
chain = saw >> svf
chain.to_wav(2, filename: "test_saw_no_oversample.wav")
puts "   Saved: test_saw_no_oversample.wav"

# With 4x oversampling
saw = Sawtooth.new(220)
svf = AudioRateSVF.new(freq: 3000.0, q: 8.0, kind: :low, drive: 24.0)
oversampled = DSP.oversample(svf, factor: 4)
chain = saw >> oversampled
chain.to_wav(2, filename: "test_saw_4x_oversample.wav")
puts "   Saved: test_saw_4x_oversample.wav"

# Test 3: Filter frequency sweep with saturation
puts "\n3. Filter sweep with heavy saturation..."

noise = Noise.new
svf = AudioRateSVF.new(freq: 200.0, q: 6.0, kind: :low, drive: 24.0)
oversampled = DSP.oversample(svf, factor: 4)
chain = noise >> oversampled
chain.to_wav(4, filename: "test_sweep_4x_oversample.wav") do |synth, progress|
  oversampled.set_freq_fast(200 + progress * 4000)
end
puts "   Saved: test_sweep_4x_oversample.wav"

puts "\nAll oversampling tests complete!"
puts "\nListen for differences:"
puts "  - Oversampled versions should sound smoother"
puts "  - Less harsh aliasing artifacts in the highs"
puts "  - Saturation should be more 'analog' sounding"
