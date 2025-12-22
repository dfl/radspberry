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
  # A simple acid synth
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

puts "1. Pattern Notation"
puts "   Playing: 'c4 e4 g4 . a3'"
puts

# Play a pattern with a specific duration per step
Synth[:basic_saw].play_pattern("c4 e4 g4 . a3", duration: 0.2.beats)

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 2: Voice Presets (Legacy / Class Wrapper)
#──────────────────────────────────────────────────────────────
# We can still use the class-based Voice presets if we prefer
# explicit object management, or we can wrap them in a Synth definition if we want.

puts "2. Acid Bassline (Synth style)"
puts "   Using simple sequence"
puts

pattern = %i[ a2 c3 a2 e3 a2 c3 a3 e3 ]

seq = SequencedSynth.new(
  voice: Voice.acid,
  sequencer: StepSequencer.new(pattern:, step_duration: 0.15)
)

Speaker.play(seq, volume: 0.4)
sleep 3
Speaker.stop

puts "   Done.\n\n"


#──────────────────────────────────────────────────────────────
# Example 3: Arpeggiator (Sequenced Synth)
#──────────────────────────────────────────────────────────────
# For complex stateful things like Arps, objects are still great.

puts "3. Arpeggiator with :c4.major chord"
puts

arp = ArpSynth.new(
  notes: :c4.major,
  step_duration: 0.1,
  mode: :up,
  octaves: 2
)

# Now we can access envelope directly
arp.voice.amp_env.attack = 0.005
arp.voice.amp_env.release = 0.1

Speaker.play(arp, volume: 0.3)
sleep 3
Speaker.stop

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 4: Arpeggiator - Up/Down with minor chord
#──────────────────────────────────────────────────────────────

puts "4. Arpeggiator - :a3.minor, Up/Down mode"
puts

arp2 = ArpSynth.new(
  notes: :a3.minor,
  step_duration: 0.08,
  mode: :up_down,
  octaves: 2
)

Speaker.play(arp2, volume: 0.3)
sleep 3
Speaker.stop

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 5: Voice.pad preset
#──────────────────────────────────────────────────────────────

puts "5. Pad sound (Voice.pad preset)"
puts

pad = Voice.pad
pad.play(:c3)

Speaker.play(pad, volume: 0.25)
sleep 2.0
pad.stop
sleep 1.5
Speaker.stop

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

lead = Voice.lead
Speaker.play(lead, volume: 0.3)

2.times do 
  [:c4, :d4, :e4, :f4].each do |note|
    lead.play(note)
    sleep 0.5.beats
  end
end

Speaker.stop
puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 8: Modulation DSL
#──────────────────────────────────────────────────────────────

puts "8. Modulation DSL"
puts "   Filter cutoff modulated by LFO"
puts

# Create a noise source and filter with LFO modulation
noise = Noise.new
lfo = Phasor.new(3)  # 3Hz LFO

# Modulate filter frequency with range
filter = ButterLP.new(1000)
           .modulate(:freq, lfo, range: 200..3000)
# Build the chain (noise >> modulated filter)
chain = noise >> filter

Speaker.play(chain, volume: 0.3)
sleep 3
Speaker.stop

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 9: Voice parameter aliases
#──────────────────────────────────────────────────────────────

puts "9. Voice parameter aliases"
puts "   Tweaking cutoff, resonance, envelope"
puts

v = Voice.acid
Speaker.play(v, volume: 0.4)

# Use parameter aliases for clean API
v.set(cutoff: 300, resonance: 0.9, attack: 0.001)
v.play(:a2)
sleep 0.3

# Sweep cutoff up
5.times do |i|
  v.cutoff = 300 + i * 400
  sleep 0.1
end

Speaker.stop
puts "   Done.\n\n"

puts "All examples complete!"
