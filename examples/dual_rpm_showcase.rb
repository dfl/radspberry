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
  v = Voice.new(osc: DualRPMOscillator)
  v.osc.window_alpha = 3.0 # High alpha for smooth, vocal quality
  v.osc.beta = 1.5
  
  # Configure Filter ADSR
  v.filter_env = Env.adsr(attack: 1.0, decay: 4.0, sustain: 0.2)
  v.cutoff = 200
  v.filter_mod = 4000
  v.res = 0.4

  # Use an LFO for a continuous smooth sweep
  lfo = Phasor.new(0.3)
  v.osc = v.osc.modulate(:sync_ratio, lfo, range: 1.0..10.0)
  
  Speaker.play(v, volume: 0.4)
  v.play(:e2)
  sleep 6.0
  v.stop
  
  Speaker.stop
end

# # 2. Kaiser Window Morphing (Aliasing Control)
# showcase "Kaiser Window Morphing (Discontinuity Control)" do
#   v = Voice.new(osc: DualRPMOscillator)
#   v.osc.sync_ratio = 4.5
#   v.osc.beta = 0.5
  
#   # Filter setup
#   v.filter_env = Env.adsr(attack: 0.5, decay: 1.0, sustain: 1.0)
#   v.cutoff = 1000
#   v.res = 0.2

#   Speaker.play(v, volume: 0.4)
#   v.play(:e2)
  
#   puts "    Alpha 0.5 (Aggressive, more aliasing)"
#   v.osc.window_alpha = 0.5
#   sleep 1.5
  
#   puts "    Alpha 8.0 (Smooth, sine-like formant)"
#   v.osc.window_alpha = 8.0
#   sleep 1.5
  
#   v.stop
#   Speaker.stop
# end

# 3. Through-Zero Linear FM
showcase "Through-Zero Linear FM (Bell Tones)" do
  v = Voice.new(osc: DualRPMOscillator)
  v.osc.sync_ratio = 1.0 # No sync displacement
  v.osc.window_alpha = 2.0
  v.osc.fm_ratio = 1.414 # Non-harmonic ratio
  v.osc.fm_linear_amt = 1.0 # 100% Linear FM
  
  # Filter Envelope
  v.filter_env = Env.adsr(attack: 0.01, decay: 0.5, sustain: 0.0)
  v.cutoff = 100
  v.filter_mod = 6000
  v.res = 0.5
  
  # Grow FM Index using an envelope
  env = AnalogADEnvelope.new(attack: 2.5, decay: 0.5)
  v.osc = v.osc.modulate(:fm_index, env, range: 0.0..4.0)
  
  Speaker.play(v, volume: 0.3)
  
  v.play(:a3)
  env.trigger!
  sleep 4.0
  v.stop
  
  Speaker.stop
end

# 4. Phase Modulation (Harmonic Richness)
showcase "Phase Modulation vs Linear FM" do
  v = Voice.new(osc: DualRPMOscillator)
  v.osc.fm_ratio = 2.0
  v.osc.fm_index = 2.0
  
  # Filter setup
  v.cutoff = 800
  v.filter_mod = 4000
  v.filter_env = Env.adsr(attack: 0.5, decay: 1.0, sustain: 0.5)

  Speaker.play(v, volume: 0.3)
  v.play(:c3)

  puts "    Pure Phase Modulation (Classic FM synthesis)"
  v.osc.fm_linear_amt = 0.0
  sleep 2.0
  
  puts "    Pure Linear FM (Brighter, through-zero)"
  v.osc.fm_linear_amt = 1.0
  sleep 2.0
  
  v.stop
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
  v = Voice.new(osc: DualRPMOscillator)
  v.osc.sync_ratio = 1.0
  v.osc.window_alpha = 4.0
  v.osc.beta = 1.5
  
  # Sweeping Filter
  v.filter_env = Env.adsr(attack: 2.0, decay: 2.0, sustain: 1.0)
  v.cutoff = 100
  v.filter_mod = 3000

  # Use a slow LFO to morph back and forth
  lfo = Phasor.new(0.5)
  v.osc = v.osc.modulate(:morph, lfo, range: 0.0..1.0)
  
  Speaker.play(v, volume: 0.4)
  v.play(:e1)
  
  puts "    Morphing smoothly from RpmSaw to RpmSquare at 0.5Hz"
  sleep 4.0
  v.stop
  
  Speaker.stop
end

# 7. PWM via Slave Offset (LFO Modulated)
showcase "PWM via Slave Offset (LFO Modulated)" do
  v = Voice.new(osc: DualRPMOscillator)
  v.osc.sync_ratio = 1.0
  v.osc.morph = 1.0 # Use square-ish base
  v.osc.beta = 1.5
  
  # Plucky filter
  v.filter_env = Env.perc(attack: 0.01, decay: 0.8)
  v.cutoff = 400
  v.filter_mod = 4000

  # Create a slow LFO for PWM
  lfo = Phasor.new(0.5) # 0.5 Hz
  
  # Modulate the 'duty' parameter
  # In DualRPM, 'duty' is the phase offset between slaves
  v.osc = v.osc.modulate(:duty, lfo, range: 0.1..0.9)
  
  Speaker.play(v, volume: 0.4)
  v.play(:c2)
  puts "    Modulating 'duty' with 0.5Hz LFO for PWM effect"
  sleep 4.0
  v.stop
  Speaker.stop
end

# 8. Envelope-Modulated Sync Ratio (Percussive Sync)
showcase "Envelope-Modulated Sync Ratio (The 'Laser' Kick)" do
  v = Voice.new(osc: DualRPMOscillator)
  v.osc.window_alpha = 4.0
  v.osc.beta = 0.8
  
  # Configure percussive filter
  v.filter_env = Env.perc(attack: 0.005, decay: 0.3)
  v.cutoff = 100
  v.filter_mod = 12000 # Massive sweep
  v.res = 0.6

  # Create an Attack-Decay envelope for sync ratio
  env = AnalogADEnvelope.new(attack: 0.01, decay: 0.4)
  
  # Modulate sync_ratio with the envelope
  # Range: 1.0 (at end of decay) to 12.0 (at peak of attack)
  v.osc = v.osc.modulate(:sync_ratio, env, range: 1.0..12.0)
  
  Speaker.play(v, volume: 0.4)
  
  puts "    Triggering Sync & Filter Envelopes"
  4.times do
    v.play(:e1)
    env.trigger!
    sleep 0.6
    v.stop
  end
  
  Speaker.stop
end

# 10. Sustained PWM + Morphing (The "Breathing" Pad)
showcase "Sustained PWM + Morphing (Dynamic Waveform Shaping)" do
  v = Voice.new(osc: DualRPMOscillator)
  v.osc.sync_ratio = 1.0
  v.osc.window_alpha = 5.0
  v.osc.beta = 1.6
  
  # Lush sweeping filter
  v.filter_env = Env.adsr(attack: 2.0, decay: 2.0, sustain: 0.8, release: 2.0)
  v.cutoff = 150
  v.filter_mod = 3500
  v.res = 0.2

  # Constant PWM + Morphing driven by separate LFOs
  lfo_pwm = Phasor.new(0.3)
  lfo_morph = Phasor.new(0.2)
  v.osc = v.osc.modulate(:duty, lfo_pwm, range: 0.2..0.8)
           .modulate(:morph, lfo_morph, range: 0.0..1.0)
  
  Speaker.play(v, volume: 0.35)
  v.play(:c2)
  
  puts "    PWM (0.3Hz) + Automatic Morphing (0.2Hz) + Filter ADSR"
  sleep 8.0
  v.stop
  
  Speaker.stop
end

# # 11. Multi-LFO Modulation (The "Bubbling" Sync)
# showcase "Multi-LFO Modulation (Sync + Alpha Phasing)" do
#   v = Voice.new(osc: DualRPMOscillator)
#   v.osc.beta = 1.2
#   v.osc.morph = 0.3
  
#   # Slow LFO for sync ratio sweep (slow "vocal" movement)
#   slow_lfo = Phasor.new(0.2)
#   # Faster LFO for window alpha (rapid "texture" movement)
#   fast_lfo = Phasor.new(1.0)

#   v.osc = v.osc.modulate(:sync_ratio, slow_lfo, range: 1.0..5.0)
#            .modulate(:window_alpha, fast_lfo, range: 1.0..10.0)
  
#   # Filter LFO modulation
#   filter_lfo = Phasor.new(0.5)
#   v.filter = v.filter.modulate(:freq, filter_lfo, range: 400..4000)

#   Speaker.play(v, volume: 0.35)
#   v.play(:e2)
#   puts "    Modulating sync_ratio (0.2Hz), window_alpha (4.0Hz), and Filter (0.5Hz)"
#   sleep 10.0
#   v.stop
#   Speaker.stop
# end

# 12. Full Chaos (Sync + FM + Feedback)
showcase "Hyper-Complex Timbres (All Params)" do
  v = Voice.new(osc: DualRPMOscillator)
  v.osc.sync_ratio = 3.33
  v.osc.window_alpha = 2.5
  v.osc.beta = 1.2
  v.osc.morph = 0.5
  v.osc.duty = 0.25
  v.osc.fm_ratio = 0.51
  v.osc.fm_index = 1.5
  v.osc.fm_feedback = 0.8 # Slave -> Master feedback
  
  # Aggressive Filter modulation
  v.filter_env = Env.adsr(attack: 1.0, decay: 0.1, sustain: 1.0)
  v.cutoff = 200
  v.filter_mod = 10000
  v.res = 0.7

  Speaker.play(v, volume: 0.4)
  v.play(:a2)
  sleep 4.0
  v.stop
  Speaker.stop
end

puts "Showcase complete."
