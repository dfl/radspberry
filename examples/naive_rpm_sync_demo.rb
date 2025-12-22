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

  env = AnalogADEnvelope.new(attack: 1.5, decay: 1.5)
  modulated = osc.modulate(:sync_ratio, env, range: 1.0..8.0)

  Speaker.play(modulated, volume: 0.4)
  env.trigger!
  sleep 3.0
  Speaker.stop
end

# 2. Index-modulated version
demo "Index-Modulated Sync (NaiveRpmSyncIndexed)" do
  osc = NaiveRpmSyncIndexed.new(:a2.freq)
  osc.sync_ratio = 3.0
  osc.exponent = 1.2

  env = AnalogADEnvelope.new(attack: 1.5, decay: 1.5)
  modulated = osc.modulate(:index, env, range: 0.5..3.0)

  Speaker.play(modulated, volume: 0.4)
  env.trigger!
  sleep 3.0
  Speaker.stop
end

# 3. Aliasing comparison via envelope sweep
demo "Aliasing Sweep (low to high sync ratio)" do
  osc = NaiveRpmSync.new(:e3.freq)
  osc.exponent = 1.0

  env = AnalogADEnvelope.new(attack: 3.0, decay: 3.0)
  modulated = osc.modulate(:sync_ratio, env, range: 2.0..20.0)

  Speaker.play(modulated, volume: 0.35)
  env.trigger!
  sleep 6.0
  Speaker.stop
end

# 4. Comparison with DualRPMOscillator
demo "Naive vs Anti-Aliased Comparison" do
  env = AnalogADEnvelope.new(attack: 1.0, decay: 1.0)

  naive = NaiveRpmSyncMorph.new(:e2.freq)
  naive.beta = 1.5
  naive_mod = naive.modulate(:sync_ratio, env, range: 1.0..8.0)

  puts "    NAIVE sync (expect some aliasing)"
  Speaker.play(naive_mod, volume: 0.4)
  env.trigger!
  sleep 2.0
  Speaker.stop

  sleep 0.3

  antialiased = DualRPMOscillator.new(:e2.freq)
  antialiased.beta = 1.5
  antialiased.window_alpha = 4.0
  aa_mod = antialiased.modulate(:sync_ratio, env, range: 1.0..8.0)

  puts "    ANTI-ALIASED sync (DualRPM with Kaiser window)"
  Speaker.play(aa_mod, volume: 0.4)
  env.trigger!
  sleep 2.0
  Speaker.stop
end

# 5. Percussive sync hits
demo "Percussive Sync Hits" do
  osc = NaiveRpmSyncMorph.new
  osc.beta = 1.2
  osc.morph = 0.3

  freq_env = AnalogADEnvelope.new(attack: 0.005, decay: 0.15)
  sync_env = AnalogADEnvelope.new(attack: 0.001, decay: 0.08)

  modulated = osc.modulate(:freq, freq_env, range: 40.0..200.0)
                 .modulate(:sync_ratio, sync_env, range: 1.0..16.0)

  Speaker.play(modulated, volume: 0.5)

  8.times do
    freq_env.trigger!
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
