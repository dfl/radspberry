#!/usr/bin/env ruby
require_relative '../lib/radspberry'
include DSP

puts <<~BANNER
  ╔════════════════════════════════════════════════════════════╗
  ║            RADSPBERRY 808 DRUM MACHINE                     ║
  ║      Demonstrating DSP::Instruments::DrumSynth             ║
  ╚════════════════════════════════════════════════════════════╝
BANNER

# 1. Instantiate Instruments
kick      = Instruments::DrumSynth.kick
snare     = Instruments::DrumSynth.snare
hat_close = Instruments::DrumSynth.hi_hat_closed
hat_open  = Instruments::DrumSynth.hi_hat_open
cowbell   = Instruments::DrumSynth.cowbell
cymbal    = Instruments::DrumSynth.cymbal
clap      = Instruments::DrumSynth.clap
maraca    = Instruments::DrumSynth.maraca
tom_low   = Instruments::DrumSynth.tom(100)
tom_high  = Instruments::DrumSynth.tom(160)

# 2. Mix them together
# We use a limiter or just simpler gain staging to avoid clipping
drums = kick * 0.8 + 
        snare * 0.7 + 
        hat_close * 0.4 + 
        hat_open * 0.4 + 
        cowbell * 0.5 + 
        cymbal * 0.4 + 
        tom_low * 0.6 + 
        tom_high * 0.6 +
        clap * 0.6 + maraca * 0.3

# 3. Start Audio Engine
Speaker.play(drums, volume: 1.0)
Clock.bpm = 120 

# 4. Sequencer Loop
live_loop :drum_machine do
  # Patterns (16 steps)
  
  # Kick: 
  k_pat = seq(0b1000_0010_1000_0000) 
  
  # Snare: 
  s_pat = seq(0b0000_1000_0000_1000)
  
  # Hats: 
  h_pat = seq(0b1111_1111_1111_1111)
  
  # Open Hat
  o_pat = seq(0b0010_0000_0010_0000)

  # Cowbell
  c_pat = seq(0b0000_0000_0011_0100)
  
  # Toms
  t_pat = seq(0b0000_0001_0000_1000)

  # Clap
  cl_pat = seq(0b0000_1000_0000_1000)

  # Maracas
  m_pat = seq(0b1101_1010_1111_0100)

  # Cymbal (Crash at start of bar)
  y_pat = seq(0b1000_0000_0000_0000)

  16.times do
    step = tick

    # Kick
    kick.play(50) if k_pat[step]

    # Snare
    snare.play if s_pat[step]

    # Hats (Exclusive)
    if o_pat[step]
      hat_open.play
    elsif h_pat[step]
      hat_close.play
    end

    # Cowbell
    cowbell.play if c_pat[step]

    # Toms
    if t_pat[step]
      (step % 2 == 0 ? tom_low : tom_high).play
    end

    # Cymbal
    cymbal.play if y_pat[step]

    # Clap
    clap.play   if cl_pat[step]

    # Maraca
    maraca.play if m_pat[step]

    sleep 0.25.beat
  end
end

puts "808 Logic initialized. Press Ctrl+C to stop."

begin
  loop { sleep 1 }
rescue Interrupt
  puts "\nStopping..."
ensure
  DSL::LiveLoop.stop_all
  Speaker.stop
end
