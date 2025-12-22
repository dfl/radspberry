require_relative '../lib/radspberry'
include DSP

puts "=== DSL Verification ==="

puts "\n1. Testing Generator#play(0.5)..."
puts "   (Should hear a short saw blip)"
begin
  SuperSaw.new(110).play(0.5)
  puts "   [OK]"
rescue => e
  puts "   [FAIL] #{e.message}"
  puts e.backtrace
end

puts "\n2. Testing Synth definition..."
begin
  Synth.define :test_synth do |freq: 440|
    SuperSaw.new(freq) >> Amp[Env.perc(attack: 0.1, decay: 0.4)]
  end
  puts "   [OK]"
rescue => e
  puts "   [FAIL] #{e.message}"
  puts e.backtrace
end

puts "\n3. Testing SynthInstance#play(0.5)..."
begin
  Synth[:test_synth, freq: 220].play(0.5)
  puts "   [OK]"
rescue => e
  puts "   [FAIL] #{e.message}"
  puts e.backtrace
end

puts "\n4. Testing Amp shorthand..."
begin
  (SuperSaw.new(330) >> Amp[Env.perc(attack: 0.1, decay: 0.2)]).play(0.5)
  puts "   [OK]"
rescue => e
  puts "   [FAIL] #{e.message}"
  puts e.backtrace
end

puts "\nDone."

puts "\n5. Testing Voice#freq= with :a3 symbol..."
begin
  v = Voice.new
  v.freq = :a3
  expected = 220.0
  if (v.freq - expected).abs < 0.1
    puts "   [OK] #{v.freq} Hz"
  else
    puts "   [FAIL] Expected #{expected}, got #{v.freq}"
  end
rescue => e
  puts "   [FAIL] #{e.message}"
end
