#!/usr/bin/env ruby
# Synth Examples - Envelopes, Sequencers, and Arpeggiators
#
# Demonstrates:
# - Analog-style ADSR envelopes (Pirkle/EarLevel method)
# - Step sequencer with classic acid bassline
# - Arpeggiator with different modes
# - Complete Voice with filter + amp envelopes

require_relative '../lib/radspberry'
include DSP

puts <<~BANNER

  ╔════════════════════════════════════════════════════════════╗
  ║         RADSPBERRY SYNTH EXAMPLES                          ║
  ╚════════════════════════════════════════════════════════════╝

BANNER

#──────────────────────────────────────────────────────────────
# Example 1: Simple envelope test
#──────────────────────────────────────────────────────────────

puts "1. Analog ADSR Envelope Test"
puts "   Attack -> Decay -> Sustain... -> Release"
puts

env = AnalogEnvelope.new(attack: 0.1, decay: 0.2, sustain: 0.6, release: 0.4)
osc = SuperSaw.new(220)

# Apply envelope to oscillator
synth = AmpEnvelope.new(osc, env)

Speaker.new(synth, volume: 0.3)
env.gate_on!
sleep 0.8
env.gate_off!
sleep 0.5
Speaker.mute

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 2: Classic acid bassline (303-style)
#──────────────────────────────────────────────────────────────

puts "2. Acid Bassline (TB-303 style)"
puts "   Sequenced notes with filter envelope"
puts

# Classic 303 pattern (A minor pentatonic)
pattern = [45, 48, 45, 52, 45, 48, 57, 52]  # MIDI notes

voice = Voice.new(
  osc_class: RpmSaw,
  filter_class: ButterLP,
  amp_attack: 0.005, amp_decay: 0.1, amp_sustain: 0.0, amp_release: 0.05,
  filter_attack: 0.001, filter_decay: 0.15,
  filter_base: 100, filter_mod: 3000
)

seq = SequencedSynth.new(
  voice: voice,
  sequencer: StepSequencer.new(pattern: pattern, step_duration: 0.15)
)

Speaker.new(seq, volume: 0.4)
sleep 3
Speaker.mute

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 3: Arpeggiator - Up mode
#──────────────────────────────────────────────────────────────

puts "3. Arpeggiator - C Major chord, Up mode, 2 octaves"
puts

arp = ArpSynth.new(
  notes: [60, 64, 67],  # C major triad
  step_duration: 0.1,
  mode: :up,
  octaves: 2
)

# Customize the voice
arp.voice.instance_variable_get(:@amp_env).attack_time = 0.005
arp.voice.instance_variable_get(:@amp_env).release_time = 0.1

Speaker.new(arp, volume: 0.3)
sleep 3
Speaker.mute

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 4: Arpeggiator - Up/Down mode
#──────────────────────────────────────────────────────────────

puts "4. Arpeggiator - Minor chord, Up/Down mode"
puts

arp2 = ArpSynth.new(
  notes: [57, 60, 64],  # A minor
  step_duration: 0.08,
  mode: :up_down,
  octaves: 2
)

Speaker.new(arp2, volume: 0.3)
sleep 3
Speaker.mute

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 5: Arpeggiator - Random mode (generative)
#──────────────────────────────────────────────────────────────

puts "5. Arpeggiator - Random mode (generative)"
puts

arp3 = ArpSynth.new(
  notes: [48, 52, 55, 60, 64, 67],  # C major extended
  step_duration: 0.12,
  mode: :random,
  octaves: 1
)

Speaker.new(arp3, volume: 0.3)
sleep 4
Speaker.mute

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 6: Pad sound with long envelopes
#──────────────────────────────────────────────────────────────

puts "6. Pad sound - Long attack/release"
puts

pad_voice = Voice.new(
  osc_class: SuperSaw,
  amp_attack: 0.8, amp_decay: 0.3, amp_sustain: 0.7, amp_release: 1.0,
  filter_attack: 0.5, filter_decay: 1.0,
  filter_base: 300, filter_mod: 2000
)

pad_voice.note_on(48)  # C3
Speaker.new(pad_voice, volume: 0.25)
sleep 2.0
pad_voice.note_off
sleep 1.5
Speaker.mute

puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 7: Plucky lead sound
#──────────────────────────────────────────────────────────────

puts "7. Plucky lead - Short attack, snappy filter"
puts

lead = Voice.new(
  osc_class: RpmSquare,
  amp_attack: 0.002, amp_decay: 0.15, amp_sustain: 0.3, amp_release: 0.1,
  filter_attack: 0.001, filter_decay: 0.08,
  filter_base: 400, filter_mod: 5000
)

# Play a simple melody
melody = [60, 64, 67, 72, 67, 64, 60, 55]
Speaker.new(lead, volume: 0.35)

melody.each do |note|
  lead.note_on(note)
  sleep 0.2
  lead.note_off
  sleep 0.05
end

Speaker.mute
puts "   Done.\n\n"

puts <<~SUMMARY
  ╔════════════════════════════════════════════════════════════╗
  ║  ALL EXAMPLES COMPLETE                                     ║
  ║                                                            ║
  ║  Try in IRB:                                               ║
  ║    arp = ArpSynth.new(notes: [60,64,67], mode: :up_down)  ║
  ║    Speaker[arp]                                            ║
  ║    arp.note_on(72)  # add a note                          ║
  ║    arp.mode = :random                                      ║
  ╚════════════════════════════════════════════════════════════╝
SUMMARY
