#!/usr/bin/env ruby
require_relative '../lib/radspberry'
include DSP

puts <<~BANNER

  ╔════════════════════════════════════════════════════════════╗
  ║           NAIVE RPM SYNC DEMO                              ║
  ║      Direct port of hardsync.pd - No anti-aliasing         ║
  ╚════════════════════════════════════════════════════════════╝

BANNER

def demo(title)
  puts "▶ Demo: #{title}"
  yield
  puts "  Done.\n\n"
end

# 1. Basic Hard Sync Sweep
demo "Basic Hard Sync Sweep (NaiveRpmSync)" do
  osc = NaiveRpmSync.new(:e2.freq)
  osc.exponent = 1.5

  Speaker.play(osc, volume: 0.4)

  puts "    Sweeping sync_ratio 1 → 8"
  20.times do |i|
    osc.sync_ratio = 1.0 + i * 0.35
    sleep 0.15
  end

  Speaker.stop
end

# 2. Index-modulated version
demo "Index-Modulated Sync (NaiveRpmSyncIndexed)" do
  osc = NaiveRpmSyncIndexed.new(:a2.freq)
  osc.sync_ratio = 3.0
  osc.exponent = 1.2

  Speaker.play(osc, volume: 0.4)

  puts "    Sweeping index 0.5 → 3"
  15.times do |i|
    osc.index = 0.5 + i * 0.17
    sleep 0.2
  end

  Speaker.stop
end

# 3. Morphable RPM (Saw to Square-ish)
demo "Morphable RPM Sync (NaiveRpmSyncMorph)" do
  osc = NaiveRpmSyncMorph.new(:c2.freq)
  osc.sync_ratio = 4.0
  osc.beta = 1.5

  Speaker.play(osc, volume: 0.4)

  puts "    Morphing from saw-like to square-like"
  20.times do |i|
    osc.morph = i / 20.0
    sleep 0.15
  end

  puts "    Morphing back"
  20.times do |i|
    osc.morph = 1.0 - i / 20.0
    sleep 0.15
  end

  Speaker.stop
end

# 4. Compare aliasing: low vs high sync ratio
demo "Aliasing Comparison (low vs high sync ratio)" do
  osc = NaiveRpmSync.new(:e3.freq)
  osc.exponent = 1.0

  Speaker.play(osc, volume: 0.35)

  puts "    Low ratio (2x) - cleaner"
  osc.sync_ratio = 2.0
  sleep 1.5

  puts "    Medium ratio (5x) - some aliasing"
  osc.sync_ratio = 5.0
  sleep 1.5

  puts "    High ratio (12x) - noticeable aliasing"
  osc.sync_ratio = 12.0
  sleep 1.5

  puts "    Extreme ratio (20x) - heavy aliasing (lo-fi!)"
  osc.sync_ratio = 20.0
  sleep 1.5

  Speaker.stop
end

# 5. Comparison with DualRPMOscillator
demo "Naive vs Anti-Aliased Comparison" do
  naive = NaiveRpmSyncMorph.new(:e2.freq)
  naive.sync_ratio = 6.0
  naive.beta = 1.5

  antialiased = DualRPMOscillator.new(:e2.freq)
  antialiased.sync_ratio = 6.0
  antialiased.beta = 1.5
  antialiased.window_alpha = 4.0

  puts "    NAIVE sync (expect some aliasing)"
  Speaker.play(naive, volume: 0.4)
  sleep 2.0
  Speaker.stop

  sleep 0.3

  puts "    ANTI-ALIASED sync (DualRPM with Kaiser window)"
  Speaker.play(antialiased, volume: 0.4)
  sleep 2.0
  Speaker.stop
end

# 6. Quick percussive hits
demo "Percussive Sync Hits" do
  osc = NaiveRpmSyncMorph.new
  osc.beta = 1.2
  osc.morph = 0.3

  # Simple amplitude envelope
  env = AnalogADEnvelope.new(attack: 0.005, decay: 0.15)
  modulated = osc.modulate(:freq, env, range: 40.0..200.0)

  sync_env = AnalogADEnvelope.new(attack: 0.001, decay: 0.08)
  modulated = modulated.modulate(:sync_ratio, sync_env, range: 1.0..16.0)

  Speaker.play(modulated, volume: 0.5)

  8.times do
    env.trigger!
    sync_env.trigger!
    sleep 0.25
  end

  Speaker.stop
end

puts "Demo complete."
puts
puts "Notes on Naive vs DualRPMOscillator:"
puts "  - Naive: Simple, low CPU, authentic lo-fi character"
puts "  - DualRPM: Kaiser windowing for anti-aliased sync sweeps"
puts "  - Use Naive for: retro sounds, CPU-limited situations, learning"
puts "  - Use DualRPM for: clean production, high sync ratios"
