require_relative '../lib/radspberry'
include DSP

puts "=== LFO and Modulation Matrix Example ===\n\n"

# Create a synth voice
osc = RpmSaw.new(220)
filter = ButterLP.new(1000, q: 3.0)
synth = osc >> filter

Speaker[synth]

# Example 1: Simple sine LFO on filter frequency
puts "1. Sine LFO modulating filter frequency (2 Hz)"
filter_lfo = LFO.sine(rate: 2.0, depth: 500, offset: 1500)

3.times do
  start_time = Time.now
  while (Time.now - start_time) < 1.0
    filter.freq = filter_lfo.tick
    sleep 0.01
  end
end

# Example 2: Triangle LFO on oscillator frequency (vibrato)
puts "\n2. Triangle LFO creating vibrato (5 Hz, ±10 Hz)"
vibrato_lfo = LFO.triangle(rate: 5.0, depth: 10, offset: 220)

3.times do
  start_time = Time.now
  while (Time.now - start_time) < 1.0
    osc.freq = vibrato_lfo.tick
    sleep 0.01
  end
end

# Example 3: Square LFO (tremolo effect using filter resonance)
puts "\n3. Square LFO on filter resonance (tremolo effect)"
tremolo_lfo = LFO.square(rate: 4.0, depth: 2, offset: 1.5)

3.times do
  start_time = Time.now
  while (Time.now - start_time) < 1.0
    filter.q = tremolo_lfo.tick
    sleep 0.01
  end
end

# Example 4: Modulation Matrix - Multiple LFOs
puts "\n4. Modulation Matrix - Multiple LFOs on different parameters"

# Create modulation matrix
matrix = ModMatrix.new

# Create multiple LFOs
freq_lfo = LFO.sine(rate: 0.5, depth: 100, offset: 0)
filter_lfo = LFO.triangle(rate: 1.5, depth: 800, offset: 0)
q_lfo = LFO.sine(rate: 0.3, depth: 1.5, offset: 0)

# Set base values
osc.freq = 220
filter.freq = 1500
filter.q = 2.0

# Connect LFOs to parameters
matrix.connect(freq_lfo, osc, :freq, depth: 1.0)
matrix.connect(filter_lfo, filter, :freq, depth: 1.0)
matrix.connect(q_lfo, filter, :q, depth: 1.0)

# Run the modulation matrix
puts "   (Running complex modulation for 5 seconds...)"
start_time = Time.now
while (Time.now - start_time) < 5.0
  matrix.tick  # Updates all connections
  sleep 0.01
end

# Example 5: Scaled and combined modulation
puts "\n5. Using LFO operators (scale, offset, invert)"

# Create LFOs with operators
slow_lfo = LFO.sine(rate: 0.25, depth: 1, offset: 0)
fast_lfo = LFO.sine(rate: 3.0, depth: 1, offset: 0)

# Scale the slow LFO for wide frequency sweeps
wide_mod = slow_lfo.scale(500)

# Scale the fast LFO for subtle vibrato
vibrato_mod = fast_lfo.scale(10)

matrix.clear!
matrix.connect(wide_mod, filter, :freq, depth: 1.0)
matrix.connect(vibrato_mod, osc, :freq, depth: 1.0)

filter.freq = 2000  # Base value
osc.freq = 220      # Base value
matrix.update_base_value(filter, :freq, 2000)
matrix.update_base_value(osc, :freq, 220)

puts "   (Wide filter sweep + fast vibrato for 5 seconds...)"
start_time = Time.now
while (Time.now - start_time) < 5.0
  matrix.tick
  sleep 0.01
end

# Example 6: Custom waveform LFO
puts "\n6. Custom waveform LFO (using sample & hold for randomness)"
random_lfo = SampleHold.new(3.0)  # Random values at 3 Hz

# Scale to useful range for filter
scaled_random = random_lfo.scale(2000).add_offset(1500)

matrix.clear!
filter.freq = 1500
matrix.connect(scaled_random, filter, :freq, depth: 1.0)
matrix.update_base_value(filter, :freq, 1500)

puts "   (Random filter jumps for 4 seconds...)"
start_time = Time.now
while (Time.now - start_time) < 4.0
  matrix.tick
  sleep 0.01
end

# Example 7: Combining automation and LFO
puts "\n7. Combining keyframe automation with LFO modulation"

# Automation controls the overall filter sweep
filter_auto = Automation.new(mode: :exponential, loop: true)
filter_auto.add_keyframe(0.0, 500)
filter_auto.add_keyframe(2.0, 3000)
filter_auto.add_keyframe(4.0, 500)

# LFO adds movement on top
movement_lfo = LFO.sine(rate: 5.0, depth: 200, offset: 0)

matrix.clear!

puts "   (Automation + LFO for 6 seconds...)"
start_time = Time.now
while (Time.now - start_time) < 6.0
  # Get automated base value
  base_freq = filter_auto.tick

  # Add LFO modulation
  filter.freq = base_freq + movement_lfo.tick

  sleep 0.01
end

puts "\nDone! Muting speaker."
Speaker.mute

puts "\n=== Summary ==="
puts "You can use:"
puts "  - Automation for precise, timed parameter changes"
puts "  - LFOs for continuous, cyclic modulation"
puts "  - ModMatrix for managing complex modulation routing"
puts "  - Combine them for expressive, dynamic synthesis!"
