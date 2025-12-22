#!/usr/bin/env ruby
# Verify that integer frequencies are treated as Hz, not MIDI notes

require_relative '../lib/radspberry'
include DSP

def verify(name, object)
  begin
    # Test with integer 110 (A2)
    object.freq = 110
    freq_hz = object.instance_variable_get(:@freq) || object.freq
    
    # If 110 was treated as MIDI, freq would be ~9400 Hz
    # If treated as Hz, freq should be 110.0
    if (freq_hz - 110.0).abs < 0.1
      puts "[OK] #{name}: 110 (Integer) -> 110.0 Hz"
    else
      puts "[FAIL] #{name}: 110 (Integer) -> #{freq_hz} Hz (interpreted as MIDI?)"
    end
  rescue => e
    puts "[ERROR] #{name}: #{e.message}"
  end
end

puts "=== Frequency Normalization Verification ==="

verify("SuperSaw", SuperSaw.new)
verify("Phasor", Phasor.new)
verify("DualRPMOscillator", DualRPMOscillator.new)
verify("NaiveRpmSync", NaiveRpmSync.new)
verify("Voice", Voice.new)
verify("ButterLP", ButterLP.new(1000))
verify("SVF", SVF.new)
verify("OnePoleZD", OnePoleZD.new)

puts "\nVerification complete."
