require_relative '../lib/radspberry'
include DSP

puts "\n=== ParamSmoother Example - Preventing Zipper Noise ==="
puts "This demonstrates exponential parameter smoothing to prevent zipper noise"
puts "when modulating filter parameters in real-time.\n"

# Create oscillator
osc = Phasor.new(110) + Phasor.new(110 * 1.495)

# Example 1: Without smoothing (may have zipper noise on very fast changes)
puts "\n1. Standard filter with built-in linear interpolation (1ms)"
lpf_standard = ButterLP.new(100, q: 2)
chain1 = osc >> lpf_standard >> Speaker

puts "   Sweeping frequency from 100Hz to 4000Hz..."
lpf_standard.freq = 100
while lpf_standard.freq < 4000
  lpf_standard.freq *= 1.05
  sleep 0.001  # Very fast changes - built-in 1ms linear interpolation
end
sleep 0.5

Speaker.mute

# Example 2: With exponential parameter smoother (smoother transition)
puts "\n2. Filter wrapped in ParamSmoother with exponential smoothing"
lpf_filter = ButterLP.new(100, q: 2)
lpf_smooth = ParamSmoother.new(lpf_filter, params: [:freq, :q], tau: 0.02)
chain2 = osc >> lpf_smooth >> Speaker

puts "   Tau = 20ms (exponential smoothing time constant)"
puts "   Sweeping frequency from 100Hz to 4000Hz with instant jumps..."

# Make INSTANT parameter jumps - the smoother will handle it
lpf_smooth.freq = 100
sleep 0.5

lpf_smooth.freq = 500
sleep 0.5

lpf_smooth.freq = 1500
sleep 0.5

lpf_smooth.freq = 4000
sleep 0.5

lpf_smooth.freq = 200
sleep 0.5

Speaker.mute

# Example 3: Smooth Q-factor modulation
puts "\n3. Smooth Q-factor modulation with fast updates"
hpf_filter = ButterHP.new(200, q: 1)
hpf_smooth = ParamSmoother.new(hpf_filter, params: [:freq, :q], tau: 0.05)
chain3 = osc >> hpf_smooth >> Speaker

puts "   Modulating Q from 0.5 to 20 with tau = 50ms"

100.times do |i|
  q_value = 0.5 + (19.5 * (0.5 + 0.5 * Math.sin(i * 0.1)))
  hpf_smooth.q = q_value
  sleep 0.01
end

Speaker.mute

# Example 4: Comparing smoothing time constants
puts "\n4. Comparing different smoothing time constants"

saw = SuperSaw.new(110)

puts "\n   4a. Fast smoothing (tau = 5ms)"
bp_fast = ButterBP.new(500, q: 5)
bp_smooth_fast = ParamSmoother.new(bp_fast, params: [:freq], tau: 0.005)
chain_fast = saw >> bp_smooth_fast >> Speaker

bp_smooth_fast.freq = 200
sleep 0.3
bp_smooth_fast.freq = 2000
sleep 0.3
bp_smooth_fast.freq = 500
sleep 0.3

Speaker.mute

puts "\n   4b. Slow smoothing (tau = 100ms) - very smooth glides"
bp_slow = ButterBP.new(500, q: 5)
bp_smooth_slow = ParamSmoother.new(bp_slow, params: [:freq], tau: 0.1)
chain_slow = saw >> bp_smooth_slow >> Speaker

bp_smooth_slow.freq = 200
sleep 0.3
bp_smooth_slow.freq = 2000
sleep 0.3
bp_smooth_slow.freq = 500
sleep 0.5  # Notice how it's still gliding

Speaker.mute

# Example 5: Convenience method for setting smoothing time in milliseconds
puts "\n5. Using smooth_time_ms convenience method"
lpf_ms = ButterLP.new(1000, q: 3)
lpf_smooth_ms = ParamSmoother.new(lpf_ms, params: [:freq, :q])
chain_ms = saw >> lpf_smooth_ms >> Speaker

lpf_smooth_ms.smooth_time_ms = 30  # 30ms smoothing time

puts "   Setting smoothing time to 30ms"
lpf_smooth_ms.freq = 300
sleep 0.5
lpf_smooth_ms.freq = 3000
sleep 0.5
lpf_smooth_ms.freq = 800
sleep 0.5

Speaker.mute

puts "\n=== ParamSmoother Demo Complete ==="
puts "\nKey points:"
puts "  - ParamSmoother wraps any filter/processor"
puts "  - Uses exponential smoothing (one-pole lowpass on parameters)"
puts "  - Tau parameter controls smoothing time constant"
puts "  - Larger tau = slower, smoother transitions"
puts "  - Prevents zipper noise even with instant parameter jumps"
puts "  - Can smooth multiple parameters simultaneously"
