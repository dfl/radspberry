require_relative '../lib/radspberry'
include DSP

puts "\n=== Function Composition with ParamSmoother ==="
puts "Modified version of example_composition.rb using exponential parameter smoothing"

osc1 = Phasor.new(110)
osc2 = Phasor.new(110 * 1.495)

# Create filter and wrap it in ParamSmoother
puts "\n1. Bandpass filter with smooth frequency sweeps"
hpf_filter = ButterBP.new(100, q: 7)
hpf = ParamSmoother.new(hpf_filter, params: [:freq, :q], tau: 0.02)
filtered = (osc1 + osc2) >> hpf >> Speaker

puts "   Sweeping up (tau = 20ms for smooth glides)"
hpf.freq = osc1.freq
while hpf.freq < Base.sample_rate/2
  hpf.freq *= 2**(1/(12.0*3))
  sleep 0.01
end

# Switch to lowpass with smoother
lpf_filter = ButterLP.new(hpf.freq, q: 7)
lpf = ParamSmoother.new(lpf_filter, params: [:freq, :q], tau: 0.03)
filtered = (osc1 + osc2) >> lpf >> Speaker

puts "\n2. Lowpass filter with extra smooth transitions"
puts "   Sweeping down (tau = 30ms for very smooth glides)"
while lpf.freq > osc1.freq
  lpf.freq *= 2**(-1/12.0)
  sleep 0.05
end

puts "\n3. Instant jumps with automatic smoothing"
puts "   Making instant frequency jumps - the smoother handles it!"
lpf.freq = 2000
sleep 0.5
lpf.freq = 500
sleep 0.5
lpf.freq = 1500
sleep 0.5
lpf.freq = 300
sleep 0.5

puts "\n4. Complex multi-stage with ParamSmoother"
saw = SuperSaw.new(110)
hp_filter = ButterHP.new(80, q: 100)
lp_filter = ButterLP.new(1000)

# Wrap both filters
hp_smooth = ParamSmoother.new(hp_filter, params: [:freq, :q], tau: 0.05)
lp_smooth = ParamSmoother.new(lp_filter, params: [:freq], tau: 0.05)

complex_chain = saw >> hp_smooth >> lp_smooth >> Speaker

puts "   Modulating both filter cutoffs simultaneously"
saw.spread = 0.7

20.times do |i|
  # Modulate both cutoff frequencies
  hp_smooth.freq = 80 + 200 * Math.sin(i * 0.3)
  lp_smooth.freq = 1000 + 500 * Math.cos(i * 0.2)
  sleep 0.1
end

Speaker.mute
puts "\n=== ParamSmoother Composition Demo Complete ==="
puts "\nCompare this with example_composition.rb to hear the difference!"
puts "The exponential smoothing provides natural-sounding glides between values."
