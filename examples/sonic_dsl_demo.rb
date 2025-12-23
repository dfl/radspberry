#!/usr/bin/env ruby
require_relative '../lib/radspberry'
include DSP

puts <<~BANNER
  ╔════════════════════════════════════════════════════════════╗
  ║         RADSPBERRY SONIC PI DSL DEMO                       ║
  ║  Showcasing Rings, Ticking, and Euclidean Rhythms          ║
  ╚════════════════════════════════════════════════════════════╝
BANNER

Clock.bpm = 130

# 1. Rings and Ticking
# --------------------
puts "1. Rings and Ticking"
puts "   Playing a circular melody using .ring and .tick"

melody = [:c3, :e3, :g3, :c4, :b3, :g3, :e3, :b2].ring
bass = [:c2, :c2, :g1, :f1].ring

lead = Voice.lead
sub  = Voice.acid

Speaker.play(lead, volume: 0.2)
Speaker.play(sub, volume: 0.3)

# Reset global counters
reset_tick

8.times do |i|
  # .tick increments the counter and returns the element at that index
  lead.note_on(melody.tick)
  
  # We can use named ticks to keep different parts in sync or independent
  # Here we tick the bass every 4 melody steps
  sub.note_on(bass.tick(:bass)) if i % 4 == 0
  
  sleep 0.25.beats
end

Speaker.stop
puts "   Done.\n\n"

# 2. Euclidean Rhythms (spread)
# -----------------------------
puts "2. Euclidean Rhythms"
puts "   Using spread(3, 8) for a classic 'Tresillo' rhythm"

# spread(pulses, steps) generates a ring of Booleans
kicks = spread(3, 8) # [T, F, F, T, F, F, T, F]
puts "   Pattern: #{kicks.to_a.map{|b| b ? 'X' : '.'}.join(' ')}"

kick = Voice.pluck
Speaker.play(kick, volume: 0.4)

16.times do
  # tick the kick pattern
  kick.note_on(:c2) if kicks.tick(:kick)
  sleep 0.25.beats
end

Speaker.stop
puts "   Done.\n\n"

# 3. Knit and Choosing
# --------------------
puts "3. Knit and Choosing"
puts "   Using knit to create structured repetitions and choose for random notes"

# knit(:val, count, :val2, count2) -> [:val, :val, :val2]
pitches = knit(:c4, 4, :g3, 4, :f3, 8).ring
scale_notes = :c4.scale(:minor_pentatonic).ring

pluck = Voice.pluck
Speaker.play(pluck, volume: 0.3)

16.times do |i|
  # Every 4th beat, choose a random note from the scale
  if i % 4 == 0
    pluck.note_on(scale_notes.choose)
  else
    pluck.note_on(pitches.tick(:pitches))
  end
  sleep 0.25.beats
end

Speaker.stop
puts "   Done.\n\n"

# 4. Ring Transformations
# -----------------------
puts "4. Ring Transformations"
puts "   Shuffling and mirroring patterns"

base_pattern = ring(:c3, :e3, :g3)
transformed = base_pattern.mirror.shuffle
puts "   Original: #{base_pattern.inspect}"
puts "   Transformed (mirror + shuffle): #{transformed.inspect}"

lead.play(:c4) # Just to hear the synth
Speaker.play(lead, volume: 0.2)

8.times do
  lead.note_on(transformed.tick(:trans))
  sleep 0.25.beats
end

Speaker.stop
puts "   Done.\n\n"
BANNER_END = <<~BANNER
  ╔════════════════════════════════════════════════════════════╗
  ║             DSL DEMO COMPLETE                              ║
  ╚════════════════════════════════════════════════════════════╝
BANNER
puts BANNER_END
