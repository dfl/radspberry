#!/usr/bin/env ruby
require_relative '../lib/radspberry'
include DSP

puts <<~BANNER
  ╔════════════════════════════════════════════════════════════╗
  ║            RADSPBERRY DRUM MACHINE                         ║
  ║     Demonstrating Sample Playback and Live Loops           ║
  ╚════════════════════════════════════════════════════════════╝
BANNER

# Initialize the global sampler mixer
# This allows 'sample' commands to be additive
# We rely on the mix below to play it.

# We can also mix in some synths
bass = Voice.acid
bass.attack = 0.02
bass.decay = 0.3
bass.sustain = 0.5
bass.release = 0.2
bass.cutoff = 3000   # Open enough to hear, low enough for bass
bass.resonance = 0.3 # Some acid squelch

# Mix Drums (via sampler_mixer) and Bass
Speaker.play(DSP.sampler_mixer * 0.8 + bass * 0.4, volume: 1.0)

# Set the tempo to a driving 130 BPM
Clock.bpm = 130

# Master Sequencer Loop
# Controls all instruments in a single thread to guarantee perfect sync.
live_loop :sequencer do
  # Patterns
  # Patterns
  # Kick: "x.......xx......" -> 1000000011000000 -> 0x80C0
  k_pat = seq(0x80C0) 
  
  # Snare: "....x.......x..." -> 0000100000001000 -> 0x0808
  s_pat = seq(0x0808)
  
  # Hats:  "x.x.x.x.x.x.x.x." -> 1010101010101010 -> 0xAAAA
  h_pat = seq(0xAAAA)
  
  # Bass:  "x.x.x.x.x.x....." -> 1010101010100000 -> 0xAAA0
  b_pat = seq(0xAAA0)
  
  # Progression
  progression = ring(:a1, :a1, :g1, :g1, :f1, :f1, :g1, :g1)
  root = progression.tick(:prog)
  
  16.times do
    # Shared step counter for this beat
    step = tick
    
    # 1. Kick
    sample :kick, amp: 1.5 if k_pat[step]
    
    # 2. Snare
    sample :snare, amp: 1.2 if s_pat[step]
    
    # 3. Hats
    if h_pat[step]
      vol = (step % 4 == 0) ? 0.5 : 0.25
      sample :hihat, rate: 1.1, amp: vol
    end
    
    # 4. Bass
    if b_pat[step]
      bass.note_on(root)
    else
      bass.note_off
    end
    
    # Wait for next step
    sleep 0.25.beat
  end
  
  # Ensure clean bass release at end of bar
  bass.note_off
end

puts "Drums and Bass running... Press Ctrl+C to stop."

begin
  loop { sleep 1 }
rescue Interrupt
  puts "\nStopping..."
ensure
  DSP::DSL::LiveLoop.stop_all
  Speaker.stop
end
