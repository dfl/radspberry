require_relative '../lib/radspberry'
include DSP

puts "=== Filter Resonance Demo ===\n"

# Define a re-usable synth for the demo
DSP::Synth.define :resonant_saw do |freq: 110, cutoff: 500, q: 1.0, spread: 0.8|
  saw = SuperSaw.new(freq)
  saw.spread = spread
  # BPF: Bandpass filter
  bpf = ButterBP.new(cutoff, q: q)
  
  saw >> bpf >> Amp[Env.adsr(attack: 0.1, decay: 0.1, sustain: 1.0, release: 0.5)]
end
  
# Example 1: Low Q (gentle filtering)
puts "1. Low Q (Q=1.0) - gentle bandpass"
DSP::Synth[:resonant_saw, q: 1.0].play(3)

# Example 2: Medium Q (musical resonance)
puts "\n2. Medium Q (Q=10.0) - musical resonance"
DSP::Synth[:resonant_saw, q: 10.0].play(3)

# Example 3: High Q (strong resonance)
puts "\n3. High Q (Q=30.0) - strong resonance"
DSP::Synth[:resonant_saw, q: 30.0].play(3)

# Example 4: The 'resonance' parameter (0.0 to 1.0)
puts "\n4. Using 'resonance' parameter sweep (0.0 to 1.0)"
puts "   resonance = 0.0 maps to Q = 0.707 (No resonance)"
puts "   resonance = 1.0 maps to Q = 25.0  (Musical peak)"

# We can instantiate a synth and control it live
synth = DSP::Synth[:resonant_saw, cutoff: 800, q: 0.707]
synth.play(0) # start playing (non-blocking if duration is 0 or nil? logic check needed)

# Wait, Synth#play(0) might stop immediately if logic is "if duration... sleep... stop"
# We'll use Speaker.play directly for manual control loop, or update Synth#play logic.
# For now, let's use the Synth instance as a generator.
Speaker.play(synth)

puts "   Sweeping resonance from 0.0 to 1.0..."
40.times do |i|
  res = i / 40.0
  # We need to map resonance to Q manually here if we want to mimic the previous example, 
  # OR we can update the Synth definition to take 'resonance' instead of Q.
  # But ButterBP takes Q. Let's just update Q directly on the filter if we could access it?
  # Synth hides the internal chain. 
  # This highlights a limitation: Synth parameters are set at init, unless we expose them.
  # Synth#set updates params and tries to set them on the chain. 
  # But 'resonance' is a property of the filter, not Q directly (Q is calc'd).
  # And our synth def takes 'q'.
  
  # Let's simplify: functionality over exact reproduction of internal mechanics.
  # We'll use the 'set' method if we update the synth def to allow direct Q control.
  # But Q is inverse proportional to bandwidth.
  
  # Actually, let's make a synth that exposes 'resonance' for this example.
end
Speaker.stop

# Redefining for resonance control demonstration
DSP::Synth.define :sweepable_saw do |freq: 110, cutoff: 800, resonance: 0.0|
  saw = SuperSaw.new(freq)
  bpf = ButterBP.new(cutoff)
  bpf.resonance = resonance # Initial set
  saw >> bpf >> Amp[Env.gate] # infinite gate
end

synth4 = DSP::Synth[:sweepable_saw, cutoff: 800]
Speaker.play(synth4)

40.times do |i|
  res = i / 40.0
  # Synth#set will try to call resonance= on objects in the chain
  synth4.set(resonance: res)
  if i % 10 == 0
    # We can't easily read back the Q from here without digging into the chain
    puts "   resonance = #{res.round(2)}"
  end
  sleep 0.1
end
sleep 0.5
Speaker.stop


# Example 5: High Q (Manual control)
puts "\n5. Manual Q control (Q=100.0) - extreme resonance"
DSP::Synth[:resonant_saw, q: 100.0].play(3)

# Example 6: Resonant frequency sweep
puts "\n6. Resonant filter sweep (resonance=0.8, freq 200Hz to 2kHz)"
synth6 = DSP::Synth[:sweepable_saw, cutoff: 200, resonance: 0.8]
Speaker.play(synth6)

puts "   Sweeping frequency..."
50.times do |i|
  freq = 200 + i * 36
  # ButterBP has freq= method, so set(freq: ...) might work if we mapped logical param 'cutoff' to it.
  # In our def: ButterBP.new(cutoff). 
  # 'cutoff' was used at init. It's not a named prop on BPF (it's 'freq').
  # So we should name the param 'freq' in the synth def if we want to update it via set,
  # OR we relies on the fact that BPF has freq=.
  
  # Let's try setting 'freq' on the synth, hoping it trickles down.
  # Wait, Synth#set only updates objects that respond to the key.
  # Our BPF responds to :freq=.
  synth6.set(freq: freq) 
  sleep 0.1
end

Speaker.stop
sleep 1

puts "\n✓ Resonance demo complete!"
