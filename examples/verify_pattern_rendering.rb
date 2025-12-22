require_relative '../lib/radspberry'
include DSP

puts "=== Pattern Timing Verification ==="

DSP::Synth.define :verify_synth do |freq: 440|
  # Super sharp attack to make trigger points visible in waveform
  SuperSaw.new(freq) >> Amp[Env.perc(attack: 0.001, decay: 0.1)]
end

s = Synth[:verify_synth]
puts "   Rendering pattern to WAV..."
s.render_pattern("c4 e4 g4 . a3", filename: "pattern_verify.wav", duration: 0.2)

puts "\n✓ Rendering complete. Please check 'pattern_verify.wav' for timing accuracy."
puts "   Each note should start exactly on the 0.2s grid (8820 samples at 44.1kHz)."
