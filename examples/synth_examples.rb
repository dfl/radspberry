#!/usr/bin/env ruby
# Synth Examples - Demonstrating the radspberry API
#
# Shows:
# - Note symbols (:c3, :a4, etc.)
# - Envelope presets (Env.perc, Env.pad)
# - Voice presets (Voice.acid, Voice.pad, Voice.pluck)
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

#──────────────────────────────────────────────────────────────
# Example 1: Note symbols and envelope presets
#──────────────────────────────────────────────────────────────

puts "1. Note Symbols & Envelope Presets"
puts "   :a3.freq = #{:a3.freq.round(2)} Hz"
puts "   :c4.major = #{:c4.major.inspect}"
puts

voice = Voice.new(
  osc: SuperSaw,
  amp_env: Env.adsr(attack: 0.1, decay: 0.2, sustain: 0.6, release: 0.4)
)

Speaker.play(voice, volume: 0.3)
voice.play(:a3)
sleep 0.8
voice.stop
sleep 0.5
Speaker.stop

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 2: Voice.acid preset
#──────────────────────────────────────────────────────────────

puts "2. Acid Bassline (Voice.acid preset)"
puts "   Using note symbols for pattern"
puts

pattern = [:a2, :c3, :a2, :e3, :a2, :c3, :a3, :e3].map(&:midi)

seq = SequencedSynth.new(
  voice: Voice.acid,
  sequencer: StepSequencer.new(pattern: pattern, step_duration: 0.15)
)

Speaker.play(seq, volume: 0.4)
sleep 3
Speaker.stop

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 3: Arpeggiator with chord helper
#──────────────────────────────────────────────────────────────

puts "3. Arpeggiator with :c4.major chord"
puts

arp = ArpSynth.new(
  notes: :c4.major.map(&:midi),
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
  notes: :a3.minor.map(&:midi),
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
# Example 6: Voice.pluck with melody
#──────────────────────────────────────────────────────────────

puts "6. Plucky lead (Voice.pluck preset)"
puts

lead = Voice.pluck
melody = [:c4, :e4, :g4, :c5, :g4, :e4, :c4, :g3]

Speaker.play(lead, volume: 0.35)

melody.each do |note|
  lead.play(note)
  sleep 0.2
  lead.stop
  sleep 0.05
end

Speaker.stop
puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 7: Timing helpers
#──────────────────────────────────────────────────────────────

puts "7. Timing helpers (Clock.bpm = #{Clock.bpm})"
puts "   1.beat = #{1.beat.round(3)}s"
puts "   1.bar  = #{1.bar.round(3)}s"
puts

lead = Voice.lead
Speaker.play(lead, volume: 0.3)

[:c4, :d4, :e4, :f4].each do |note|
  lead.play(note)
  sleep 0.5.beats
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

v.stop
sleep 0.3
Speaker.stop

puts "   Done.\n\n"

puts <<~SUMMARY
  ╔═════════════════════════════════════════════════════╗
  ║  ALL EXAMPLES COMPLETE                              ║
  ║                                                     ║
  ║  API highlights:                                    ║
  ║                                                     ║
  ║  Notes & Scales:                                    ║
  ║    :c4.freq              # => 261.63                ║
  ║    :c4.major             # => [:c4, :e4, :g4]       ║
  ║    :c4.scale(:blues)     # blues scale              ║
  ║    :c4 + 7               # => :g4 (transpose)       ║
  ║                                                     ║
  ║  Voice Presets:                                     ║
  ║    Voice.acid(:a2)       # instant 303              ║
  ║    Voice.pad(:c3)        # lush pad                 ║
  ║    Voice.pluck(:e4)      # plucky sound             ║
  ║    Voice.lead(:g4)       # mono lead                ║
  ║                                                     ║
  ║  Voice Parameters:                                  ║
  ║    v.cutoff = 2000       # filter frequency         ║
  ║    v.resonance = 0.8     # filter Q                 ║
  ║    v.set(attack: 0.01)   # bulk update              ║
  ║                                                     ║
  ║  Modulation DSL:                                    ║
  ║    filter.modulate(:freq, lfo, range: 200..4000)   ║
  ║                                                     ║
  ║  Envelopes:                                         ║
  ║    Env.perc              # quick hit                ║
  ║    Env.pad               # slow envelope            ║
  ║                                                     ║
  ║  Timing:                                            ║
  ║    Clock.bpm = 140                                  ║
  ║    sleep 1.beat                                     ║
  ╚═════════════════════════════════════════════════════╝
SUMMARY
