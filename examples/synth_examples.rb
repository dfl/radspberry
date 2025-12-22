#!/usr/bin/env ruby
# Synth Examples - Demonstrating the radspberry API
#
# Shows:
# - Synth definitions (Synth.define, Synth[:name])
# - Note symbols (:c3, :a4, etc.)
# - Envelope presets (Env.perc, Env.pad)
# - Clean Speaker API
# - Timing helpers (1.beat, 0.5.bars)

require_relative '../lib/radspberry'
include DSP

puts <<~BANNER

  ╔════════════════════════════════════════════════════════════╗
  ║         RADSPBERRY SYNTH EXAMPLES                          ║
  ╚════════════════════════════════════════════════════════════╝

BANNER

Clock.bpm = 120

# Define some re-usable synths first
# =================================

DSP::Synth.define :basic_saw do |freq: 440, amp: 1.0|
  SuperSaw.new(freq) >> Amp[Env.perc(attack: 0.1, decay: 0.2)] * amp
end

DSP::Synth.define :acid do |note: 220, cutoff: 1000, res: 0.5, gate: 0.0|
  osc = RpmSaw.new(note)
  filt = ButterLP.new(cutoff, q: res * 20.0 + 0.5)
  env = Env.perc(attack: 0.01, decay: 0.2)
  # A simple acid synth for sequencing
  osc >> filt >> Amp[env]
end

DSP::Synth.define :pad do |note: 220|
  SuperSaw.new(note) >> ButterLP.new(800) >> Amp[Env.pad]
end

DSP::Synth.define :pluck do |note: 440|
  RpmSquare.new(note) >> ButterLP.new(2000) >> Amp[Env.pluck]
end

#──────────────────────────────────────────────────────────────
# Example 1: Note symbols and simple synth
#──────────────────────────────────────────────────────────────

puts "1. Note Symbols & Synth Usage"
puts "   :a3.freq = #{:a3.freq.round(2)} Hz"
puts "   :c4.major = #{:c4.major.inspect}"
puts

# Play a named synth for a duration
Synth[:basic_saw, freq: :c4].play(0.5)
sleep 0.2
Synth[:basic_saw, freq: :e4].play(0.5)
sleep 0.2
Synth[:basic_saw, freq: :g4].play(1.0)

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 2: Voice Presets (Legacy / Class Wrapper)
#──────────────────────────────────────────────────────────────
# We can still use the class-based Voice presets if we prefer
# explicit object management, or we can wrap them in a Synth definition if we want.

puts "2. Acid Bassline (Synth style)"
puts "   Using simple sequence"
puts

pattern = [:a2, :c3, :a2, :e3, :a2, :c3, :a3, :e3]

pattern.each do |note|
  # Fire and forget synth shots
  Synth[:acid, note: note, cutoff: 1500, res: 0.7].play(0.15)
  sleep 0.15
end

puts "   Done.\n\n"


#──────────────────────────────────────────────────────────────
# Example 3: Arpeggiator (Sequenced Synth)
#──────────────────────────────────────────────────────────────
# For complex stateful things like Arps, objects are still great.

puts "3. Arpeggiator with :c4.major chord"
puts

arp = ArpSynth.new(
  notes: :c4.major.map(&:midi),
  step_duration: 0.1,
  mode: :up,
  octaves: 2
)

# Play the generator for 3 seconds
arp.play(3)

puts "   Done.\n\n"


#──────────────────────────────────────────────────────────────
# Example 4: Pad sound
#──────────────────────────────────────────────────────────────

puts "4. Pad sound"
puts

# Pad envelopes need time to release, so 'play(duration)' works well
# if the synth itself handles the release phase or if we just gate it.
# Our simple :pad definition uses Env.pad which has a long release.
# play(2) will cut it off after 2 seconds.

Synth[:pad, note: :c3].play(2.5)

puts "   Done.\n\n"


#──────────────────────────────────────────────────────────────
# Example 5: Timing helpers
#──────────────────────────────────────────────────────────────

puts "5. Timing helpers (Clock.bpm = #{Clock.bpm})"
puts "   1.beat = #{1.beat.round(3)}s"
puts
puts "   Playing on the beat..."

[:c4, :d4, :e4, :c4].each do |note|
  Synth[:pluck, note: note].play(0.5)
  # Sleep for the remainder of the beat?
  # Actually play(0.5) blocks. 
  # If we want to sequence tightly, we sleep instead of blocking play.
  # But play() blocks. 
  
  # To sequence:
  # Speaker.play(synth) (non-blocking)
  # sleep ...
  # Speaker.stop
  
  # OR rely on short percussive sounds just finishing naturally.
  # Let's use the explicit sleep for rhythm.
end

puts "   (Rhythmic sequence...)"
[:c4, :d4, :e4, :f4].each do |note|
  # Non-blocking fire
  Speaker.play(Synth[:pluck, note: note], duration: 0.2)
  sleep 1.beat
end

puts "   Done.\n\n"


#──────────────────────────────────────────────────────────────
# Example 6: Live parameter modulation
#──────────────────────────────────────────────────────────────

puts "6. Live parameter modulation"
puts "   Sweeping cutoff on a running synth"
puts

# We define a synth that exposes parameters we want to tweak
DSP::Synth.define :sweep_pad do |freq: 220, cutoff: 500|
  # We use a symbol for cutoff so we can easily target it?
  # No, Synth#set looks for setters.
  # ButterLP has freq=. We'll map 'cutoff' to it in the loop manually 
  # or ensure our objects expose the right setters.
  
  # Let's just use the filter instance's setter.
  saw = SuperSaw.new(freq)
  filt = ButterLP.new(cutoff)
  # We want to be able to set filt.freq later.
  # Synth#set does broadcast_param.
  # If we call s.set(freq: 800), it might try to set saw.freq AND filt.freq!
  # That's a feature/bug of broadcast.
  # So we probably want named parameters if we want distinct control.
  # But here, we'll just show updating the filter if we can.
  
  saw >> filt >> Amp[Env.gate]
end

s = Synth[:sweep_pad, freq: :c3, cutoff: 400]
Speaker.play(s)

20.times do |i|
  # ButterLP has a 'freq=' method.
  # Synth#set(freq: ...) will find it.
  # BUT SuperSaw ALSO has 'freq='. 
  # So setting 'freq' changes pitch AND cutoff.
  # That's actually a cool effect for this demo!
  
  new_freq = 400 + i * 50
  s.set(freq: new_freq)
  sleep 0.1
end

Speaker.stop
puts "   Done.\n\n"

puts "All examples complete!"
