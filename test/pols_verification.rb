require_relative '../lib/radspberry'
include DSP

# 1. Frequency Normalization
puts "Checking Frequency Normalization..."
puts "440 Hz: #{DSP.to_freq(440)}"
puts ":a4 note: #{DSP.to_freq(:a4)}"
puts "69 MIDI: #{DSP.to_freq(69)}"

# 2. Timing Aliases
puts "\nChecking Timing Aliases..."
puts "1.beat: #{1.beat}"
puts "1.second: #{1.second}"
puts "4.seconds: #{4.seconds}"
puts "500.ms: #{500.ms}"

# 3. Voice initialize and play
v = Voice.new(osc: RpmSaw) # Should work
puts "\nVoice created with class RpmSaw"

# 4. Envelope gate=
env = Env.adsr
env.gate = true
puts "Env state after gate = true: #{env.state}" # Should be ATTACK (1)
env.gate = false
puts "Env state after gate = false: #{env.state}" # Should be RELEASE (4)

# 5. Frequency in Oscillator
osc = Phasor.new
osc.freq = :c3
puts "Osc freq after setting :c3: #{osc.freq}"

# 6. Frequency in Filter
filter = ButterLP.new
filter.freq = :g4
puts "Filter freq after setting :g4: #{filter.freq}"

puts "\nVerification complete (Dry run - no audio)"
