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

# Clock.bpm = 120

# Define some re-usable synths first
# =================================

DSP::Synth.define :basic_saw do |freq: 440, amp: 1.0|
  SuperSaw.new(freq) >> Amp[Env.perc(attack: 0.1, decay: 0.2)] * amp
end

DSP::Synth.define :acid do |freq: :c2, cutoff: 250, res: 0.5, resonance: nil, attack: nil|
  # Support aliases
  res = resonance if resonance
  atk = attack || 0.005 # Default attack

  # Acid sound: RpmSaw -> Lowpass with resonance -> Envelope
  # Matched precisely to Voice.acid preset
  osc = RpmSaw.new(freq)
  
  # Filter envelope: snappy percussive pip
  f_env = Env.perc(attack: 0.001, decay: 0.15)
  
  # Amp envelope: short ADSR
  # Use 'atk' for attack time
  a_env = Env.adsr(attack: atk, decay: 0.1, sustain: 0.0, release: 0.05)
  
  # Filter modulation: base 250Hz + (0..1 * 3500Hz)
  filt = ButterLP.new(cutoff)
  filt.q = res * 15.0 + 0.5 # Map 0..1 res to 0.5..15.5 Q
  
  osc >> 
    filt.modulate(:freq, f_env, range: cutoff..(cutoff + 3500)) >> 
    Amp[a_env]
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

puts "1. Pattern Notation (with Ties & Legato)"
puts "   Playing: 'c4 e4 g4 c5 . g4 c5- .'"
puts

# play_pattern is non-blocking (audio runs in background).
# We call .wait to pause the Ruby script until the pattern finishes.
# Notation:
#   'c4~'     Tie: holds c4 for 2 beats
#   'c4~e4'   Legato: transitions to e4 without re-triggering envelope
#   '.'       Rest: silence
Synth[:basic_saw].play_pattern("c4 e4 g4 c5 . g4 c5- .", duration: 0.3.beats).wait
puts "   Done.\n\n"

#──────────────────────────────────────────────────────────────
# Example 2: Voice Presets (Legacy / Class Wrapper)
#──────────────────────────────────────────────────────────────
# We can still use the class-based Voice presets if we prefer
# explicit object management, or we can wrap them in a Synth definition if we want.


puts "2. Acid Bassline (Pattern DSL)"
puts "   Using Synth[:acid] with pattern 'a2 c3 a2 e3 a2 c3 a3 e3'"
puts

Synth[:acid].play_pattern("a2 c3 a2 e3 a2 c3 a3 e3", duration: 0.3.beats).wait

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

# puts "5. Pad sound (Voice.pad preset)"
# puts

# pad = Voice.pad
# pad.play(:c3)

# Speaker.play(pad, volume: 0.25)
# sleep 2.0
# pad.stop
# sleep 1.5
# Speaker.stop

# puts "   Done.\n\n"


#──────────────────────────────────────────────────────────────
# Example 4: Pad sound
#──────────────────────────────────────────────────────────────

puts "5. Pad sound"
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

puts "6. Timing helpers (Clock.bpm = #{Clock.bpm})"
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

puts "7. Modulation DSL"
puts "   Filter cutoff modulated by LFO"
puts "   LFO rate ramping exponentially from 1Hz to 30Hz"
puts

# Create a noise source
noise = Noise.new

# Create an exponential ramp for LFO rate modulation
lfo_rate_mod = Env.linexp(1, 30, 3.seconds)

# Create an LFO whose rate is modulated by the ramp
lfo = Phasor.new(1).modulate(:freq, lfo_rate_mod)

# Modulate filter frequency with LFO
filter = ButterLP.new(1000)
           .modulate(:freq, lfo, range: 200..3000)

# Build the chain
chain = noise >> filter

Speaker.play(chain, volume: 0.3)
sleep 4
Speaker.stop

puts "   Done.\n\n"

puts "All examples complete!"
