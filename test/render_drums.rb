require_relative '../lib/radspberry'
include DSP

def render_drum(name, inst, duration=2.0)
  filename = "test/output/#{name}.wav"
  puts "Rendering #{name} to #{filename}..."
  
  # Trigger the drum at the start
  inst.play
  
  # Render to WAV
  inst.to_wav(duration, filename: filename)
end

# Ensure directory exists
`mkdir -p test/output`

# Define instruments
drums = {
  kick:      Instruments::DrumSynth.kick,
  snare:     Instruments::DrumSynth.snare,
  hat_closed: Instruments::DrumSynth.hi_hat_closed,
  hat_open:  Instruments::DrumSynth.hi_hat_open,
  cymbal:    Instruments::DrumSynth.cymbal,
  cowbell:   Instruments::DrumSynth.cowbell,
  clap:      Instruments::DrumSynth.clap,
  maraca:    Instruments::DrumSynth.maraca,
  tom:       Instruments::DrumSynth.tom(100)
}

drums.each do |name, inst|
  render_drum(name, inst)
end

puts "Done. Check test/output/ for WAV files."
