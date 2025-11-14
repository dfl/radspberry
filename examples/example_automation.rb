require_relative '../lib/radspberry'
include DSP

puts "=== Keyframe Automation Example ===\n\n"

# Create a simple synth
osc = RpmSaw.new(220)
filter = ButterLP.new(2000, q: 2.0)
synth = osc >> filter

Speaker[synth]

# Example 1: Linear frequency sweep
puts "1. Linear frequency automation (220 Hz -> 440 Hz over 2 seconds)"
freq_auto = Automation.new(mode: :linear)
freq_auto.add_keyframe(0.0, 220)
freq_auto.add_keyframe(2.0, 440)
freq_auto.add_keyframe(4.0, 220)

# Manual automation loop
start_time = Time.now
while (Time.now - start_time) < 4.0
  osc.freq = freq_auto.tick
  sleep 0.01  # Update ~100 times per second
end

# Example 2: Exponential filter sweep (better for frequency-based parameters)
puts "\n2. Exponential filter sweep (500 Hz -> 5000 Hz over 3 seconds)"
filter_auto = Automation.new(mode: :exponential)
filter_auto.add_keyframe(0.0, 500)
filter_auto.add_keyframe(1.5, 5000)
filter_auto.add_keyframe(3.0, 500)

start_time = Time.now
while (Time.now - start_time) < 3.0
  filter.freq = filter_auto.tick
  sleep 0.01
end

# Example 3: Step automation (like a sequencer)
puts "\n3. Step automation (chromatic scale)"
step_auto = Automation.new(mode: :step)
notes = [220, 246.94, 277.18, 293.66, 329.63, 349.23, 392.00, 440]
notes.each_with_index do |freq, i|
  step_auto.add_keyframe(i * 0.5, freq)
end

start_time = Time.now
while (Time.now - start_time) < 4.0
  osc.freq = step_auto.tick
  sleep 0.01
end

# Example 4: Cubic interpolation (smooth S-curves)
puts "\n4. Cubic interpolation (smooth filter modulation)"
cubic_auto = Automation.new(mode: :cubic)
cubic_auto.add_keyframe(0.0, 1000)
cubic_auto.add_keyframe(1.0, 4000)
cubic_auto.add_keyframe(2.0, 500)
cubic_auto.add_keyframe(3.0, 3000)

start_time = Time.now
while (Time.now - start_time) < 3.0
  filter.freq = cubic_auto.tick
  sleep 0.01
end

# Example 5: Looping automation
puts "\n5. Looping automation (continuous cycle)"
loop_auto = Automation.new(mode: :linear, loop: true)
loop_auto.add_keyframe(0.0, 220)
loop_auto.add_keyframe(0.5, 440)
loop_auto.add_keyframe(1.0, 220)

start_time = Time.now
while (Time.now - start_time) < 3.0
  osc.freq = loop_auto.tick
  sleep 0.01
end

puts "\nDone! Muting speaker."
Speaker.mute
