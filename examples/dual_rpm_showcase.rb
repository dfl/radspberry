#!/usr/bin/env ruby
require_relative '../lib/radspberry'
include DSP

puts <<~BANNER

  ╔════════════════════════════════════════════════════════════╗
  ║         DUAL RPM OSCILLATOR SHOWCASE                       ║
  ║    Hard Sync • Kaiser Windowing • Through-Zero FM          ║
  ╚════════════════════════════════════════════════════════════╝

BANNER

Clock.bpm = 120

# We use a simple Speaker.play setup for each demo
def showcase(title)
  puts "▶ Showcase: #{title}"
  yield
  puts "  Done.\n\n"
end

# 1. Classic Hard Sync Sweep
showcase "Classic Hard Sync Sweep (Vocal Formants)" do
  osc = DualRPMOscillator.new(:e2.freq)
  osc.window_alpha = 3.0 # High alpha for smooth, vocal quality
  osc.beta = 1.5
  
  Speaker.play(osc, volume: 0.4)
  
  # Sweep sync_ratio from 1.0 to 10.0
  steps = 60
  duration = 3.0
  steps.times do |i|
    osc.sync_ratio = 1.0 + 9.0 * (i.to_f / steps)
    sleep duration / steps
  end
  
  Speaker.stop
end

# 2. Kaiser Window Morphing (Aliasing Control)
showcase "Kaiser Window Morphing (Discontinuity Control)" do
  osc = DualRPMOscillator.new(:e2.freq)
  osc.sync_ratio = 4.5
  osc.beta = 0.5
  
  Speaker.play(osc, volume: 0.4)
  
  puts "    Alpha 0.5 (Aggressive, more aliasing)"
  osc.window_alpha = 0.5
  sleep 1.5
  
  puts "    Alpha 8.0 (Smooth, sine-like formant)"
  osc.window_alpha = 8.0
  sleep 1.5
  
  Speaker.stop
end

# 3. Through-Zero Linear FM
showcase "Through-Zero Linear FM (Bell Tones)" do
  osc = DualRPMOscillator.new(:a3.freq)
  osc.sync_ratio = 1.0 # No sync displacement
  osc.window_alpha = 2.0
  osc.fm_ratio = 1.414 # Non-harmonic ratio
  osc.fm_linear_amt = 1.0 # 100% Linear FM
  
  Speaker.play(osc, volume: 0.3)
  
  # Grow FM Index
  8.times do |i|
    osc.fm_index = i * 0.5
    sleep 0.3
  end
  
  Speaker.stop
end

# 4. Phase Modulation (Harmonic Richness)
showcase "Phase Modulation vs Linear FM" do
  osc = DualRPMOscillator.new(:c3.freq)
  osc.fm_ratio = 2.0
  osc.fm_index = 2.0
  
  Speaker.play(osc, volume: 0.3)
  
  puts "    Pure Phase Modulation (Classic FM synthesis)"
  osc.fm_linear_amt = 0.0
  sleep 2.0
  
  puts "    Pure Linear FM (Brighter, through-zero)"
  osc.fm_linear_amt = 1.0
  sleep 2.0
  
  Speaker.stop
end

# # 5. Recursive PM (The RPM Magic)
# showcase "Recursive Phase Modulation (Beta Sweep)" do
#   osc = DualRPMOscillator.new(:e2.freq)
#   osc.sync_ratio = 1.0
#   osc.window_alpha = 3.0
  
#   Speaker.play(osc, volume: 0.4)
  
#   puts "    Increasing Internal Feedback (Beta)"
#   10.times do |i|
#     osc.beta = i * 0.2
#     sleep 0.4
#   end
  
#   Speaker.stop
# end

# 6. Saw-Square Morphing (RPM Core Morph)
showcase "Saw-Square Morphing (RPM Core Dynamics)" do
  osc = DualRPMOscillator.new(:e1.freq)
  osc.sync_ratio = 1.0
  osc.window_alpha = 4.0
  osc.beta = 1.5
  
  Speaker.play(osc, volume: 0.4)
  
  puts "    Morphing from RpmSaw (0.0) to RpmSquare (1.0)"
  steps = 40
  steps.times do |i|
    osc.morph = i.to_f / steps
    sleep 0.05
  end
  sleep 1.0
  
  Speaker.stop
end

# 7. PWM via Slave Offset (LFO Modulated)
showcase "PWM via Slave Offset (LFO Modulated)" do
  osc = DualRPMOscillator.new(:c2.freq)
  osc.sync_ratio = 1.0
  osc.morph = 1.0 # Use square-ish base
  osc.beta = 1.5
  
  # Create a slow LFO for PWM
  lfo = Phasor.new(0.5) # 0.5 Hz
  
  # Modulate the 'duty' parameter
  # In DualRPM, 'duty' is the phase offset between slaves
  osc.modulate(:duty, lfo, range: 0.1..0.9)
  
  Speaker.play(osc, volume: 0.4)
  puts "    Modulating 'duty' with 0.5Hz LFO for PWM effect"
  sleep 4.0
  Speaker.stop
end

# 8. Envelope-Modulated Sync Ratio (Percussive Sync)
showcase "Envelope-Modulated Sync Ratio (The 'Laser' Kick)" do
  osc = DualRPMOscillator.new(:e1.freq) # Very low base note
  osc.window_alpha = 4.0
  osc.beta = 0.8
  
  # Create an Attack-Decay envelope
  env = AnalogADEnvelope.new(attack: 0.01, decay: 0.4)
  
  # Modulate sync_ratio with the envelope
  # Range: 1.0 (at end of decay) to 12.0 (at peak of attack)
  osc.modulate(:sync_ratio, env, range: 1.0..12.0)
  
  Speaker.play(osc, volume: 0.4)
  
  puts "    Triggering Sync Envelope"
  4.times do
    env.trigger!
    sleep 0.6
  end
  
  Speaker.stop
end

# 10. Sustained PWM + Morphing (The "Breathing" Pad)
showcase "Sustained PWM + Morphing (Dynamic Waveform Shaping)" do
  osc = DualRPMOscillator.new(:c2.freq)
  osc.sync_ratio = 1.0
  osc.window_alpha = 5.0
  osc.beta = 1.6
  
  # Slow LFO for constant PWM motion
  lfo = Phasor.new(0.3)
  osc.modulate(:duty, lfo, range: 0.2..0.8)
  
  Speaker.play(osc, volume: 0.35)
  
  puts "    Starting with Saw (morph=0.0) + PWM"
  osc.morph = 0.0
  sleep 2.0
  
  puts "    Slowly Morphing to Square (morph=1.0) while PWM continues"
  steps = 50
  steps.times do |i|
    osc.morph = i.to_f / steps
    sleep 0.1
  end
  
  puts "    Now at Pure Square + PWM"
  sleep 2.0
  
  Speaker.stop
end

# 11. Multi-LFO Modulation (The "Bubbling" Sync)
showcase "Multi-LFO Modulation (Sync + Alpha Phasing)" do
  osc = DualRPMOscillator.new(:e2.freq)
  osc.beta = 1.2
  osc.morph = 0.3
  
  # Slow LFO for sync ratio sweep (slow "vocal" movement)
  slow_lfo = Phasor.new(0.2)
  osc.modulate(:sync_ratio, slow_lfo, range: 1.0..5.0)
  
  # Faster LFO for window alpha (rapid "texture" movement)
  fast_lfo = Phasor.new(1.0)
  osc.modulate(:window_alpha, fast_lfo, range: 1.0..10.0)
  
  Speaker.play(osc, volume: 0.35)
  puts "    Modulating sync_ratio (0.2Hz) and window_alpha (4.0Hz)"
  sleep 10.0
  Speaker.stop
end

# 12. Full Chaos (Sync + FM + Feedback)
showcase "Hyper-Complex Timbres (All Params)" do
  osc = DualRPMOscillator.new(:a2.freq)
  osc.sync_ratio = 3.33
  osc.window_alpha = 2.5
  osc.beta = 1.2
  osc.morph = 0.5
  osc.duty = 0.25
  osc.fm_ratio = 0.51
  osc.fm_index = 1.5
  osc.fm_feedback = 0.8 # Slave -> Master feedback
  
  Speaker.play(osc, volume: 0.4)
  sleep 4.0
  Speaker.stop
end

puts "Showcase complete."
