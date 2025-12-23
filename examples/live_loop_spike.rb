# Set to true to see sync/cue events in the console
$DEBUG_DSL = false 

require_relative '../lib/radspberry'
include DSP

puts <<~BANNER
  ╔════════════════════════════════════════════════════════════╗
  ║         RADSPBERRY LIVE LOOP SPIKE (FIXED)                 ║
  ║  Demonstrating concurrent loops and synchronization        ║
  ╚════════════════════════════════════════════════════════════╝
BANNER

Clock.bpm = 120

# Create voices
$kick = Voice.acid
$snare = Voice.pluck
$melody = Voice.lead

# Mix them together
Speaker.play($kick + $snare + $melody, volume: 0.4)

# Define loops
live_loop :metronome do
  t = tick(:beat)
  puts "\n[Metronome] BEAT #{t}"
  cue :beat
  sleep 1.beat
end

live_loop :kick do
  sync :beat
  puts "  (Kick)"
  $kick.note_on(:c2)
end

live_loop :snare do
  sync :beat
  sleep 0.5.beat
  puts "  (Snare)"
  $snare.note_on(:c3)
end

notes = ring(:c4, :e4, :g4, :c5)
live_loop :lead do
  sync :beat
  n = notes.tick(:mel)
  puts "  (Melody: #{n})"
  $melody.note_on(n)
  sleep 0.25.beat
  n2 = notes.tick(:mel)
  puts "  (Melody: #{n2})"
  $melody.note_on(n2)
end

$stdout.sync = true # Ensure we see output immediately

puts "Loops running. Press Ctrl+C to stop."
begin
  loop { sleep 1 }
rescue Interrupt
  puts "\nStopping..."
ensure
  DSP::DSL::LiveLoop.stop_all
  Speaker.stop
end
