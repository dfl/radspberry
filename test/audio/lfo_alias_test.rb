#!/usr/bin/env ruby
# LFO frequency modulation test for aliasing detection
# If aliasing: high tones move DOWN as fundamental moves UP
# If clean: only the fundamental pitch changes

require_relative '../../lib/radspberry'
include DSP

puts "=== LFO Frequency Modulation Aliasing Test ==="
puts "A slow LFO (0.2 Hz) modulates SuperSaw frequency between 200-800 Hz"
puts 
puts "LISTEN FOR:"
puts "  Clean: smooth pitch wobble, no extra tones"
puts "  Aliasing: high-pitched whine that moves OPPOSITE to the pitch"
puts

center_freq = 110.0

# Create SuperSaw with and without oversampling to compare
saw = SuperSaw.new(center_freq, oversample: false, polyblep: false)

# Debug
master = saw.instance_variable_get(:@master)
puts "Debug:"
puts "  master.srate: #{master.srate}"
puts "  master.freq: #{master.freq}"  
puts "  master @inc: #{master.instance_variable_get(:@inc)}"
puts "  Correct @inc: #{master.freq.to_f / master.srate}"
puts

# Manual LFO - sine wave at 0.2 Hz
lfo_freq = 0.2
lfo_phase = 0.0
mod_depth = 10.0  # ±300 Hz

saw >> Speaker

puts "Playing for 8 seconds with LFO modulation..."
puts "Press Ctrl+C to stop"

start_time = Time.now
loop do
  elapsed = Time.now - start_time
  break if elapsed > 8
  
  # Update LFO 
  lfo_phase += lfo_freq * 0.05  # 20 updates/sec
  lfo_value = Math.sin(2 * Math::PI * lfo_phase)
  
  new_freq = center_freq + mod_depth * lfo_value
  saw.freq = new_freq
  
  print "\r  Freq: #{new_freq.round(0)} Hz  LFO: #{(lfo_value * 100).round(0)}%  "
  
  sleep 0.05
end

puts "\n\nTest complete."
Speaker.stop
