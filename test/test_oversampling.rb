require_relative '../lib/radspberry'
include DSP

puts "Testing 4x oversampling..."

# Test 1: Compare saturated filter with and without oversampling
puts "\n1. Saturated filter comparison..."

# Without oversampling
noise = Noise.new
svf = AudioRateSVF.new(freq: 2000.0, q: 4.0, kind: :low, drive: 18.0)
chain = noise >> svf
chain.to_wav(2, filename: "test_no_oversample.wav")
puts "   Saved: test_no_oversample.wav (no oversampling)"

# With 4x oversampling (wrapping just the filter)
noise = Noise.new
svf = AudioRateSVF.new(freq: 2000.0, q: 4.0, kind: :low, drive: 18.0)
oversampled = DSP.oversample(svf)
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
oversampled = DSP.oversample(svf)
chain = saw >> oversampled
chain.to_wav(2, filename: "test_saw_4x_oversample.wav")
puts "   Saved: test_saw_4x_oversample.wav"

# Test 3: OversampledChain - entire chain at 4x
puts "\n3. OversampledChain - entire chain runs at 4x..."

chain = DSP.oversampled do
  noise = Noise.new
  svf = AudioRateSVF.new(freq: 2000.0, q: 4.0, kind: :low, drive: 18.0)
  noise >> svf
end
chain.to_wav(2, filename: "test_chain_4x.wav")
puts "   Saved: test_chain_4x.wav (whole chain at 4x)"
puts "   Internal sample rate was: #{chain.factor * 44100}Hz"

# Test 4: Filter sweep with OversampledChain
puts "\n4. Filter sweep with OversampledChain..."

# Store reference to filter for modulation
svf_ref = nil
chain = DSP.oversampled do
  noise = Noise.new
  svf_ref = AudioRateSVF.new(freq: 200.0, q: 6.0, kind: :low, drive: 24.0)
  noise >> svf_ref
end
chain.to_wav(4, filename: "test_chain_sweep.wav") do |synth, progress|
  svf_ref.set_freq_fast(200 + progress * 4000)
end
puts "   Saved: test_chain_sweep.wav"

puts "\nAll oversampling tests complete!"
puts "\nListen for differences:"
puts "  - Oversampled versions should sound smoother"
puts "  - Less harsh aliasing artifacts in the highs"
puts "  - Saturation should be more 'analog' sounding"
