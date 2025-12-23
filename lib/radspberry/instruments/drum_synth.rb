module DSP
  module Instruments
    class SwingVCA < DSP::Generator
      def initialize
        @dc_block = DSP::DCBlocker.new
      end

      def process(sig)
        # Half-wave rectification
        rectified = sig > 0.0 ? sig : 0.0
        # DC Blocking (essential after rectification)
        @dc_block.tick(rectified)
      end

      def srate=(rate)
        @dc_block.clear!
      end
    end

    class MetallicNoise < DSP::Generator
      def initialize
        # 808 Metallic Noise uses 6 raw square wave oscillators
        # Using DSP::Pulse for "logic-level" transitions
        @oscs = [263, 400, 421, 474, 587, 845].map do |f|
          DSP::Pulse.new(f, 0.5)
        end
        # Summing normalized to 1.0
        @gain = 1.0 / 6.0
      end

      def tick
        # Sum 6 square waves (bipolar -1..1)
        sig = @oscs.sum { |osc| osc.tick }
        sig * @gain
      end

      def srate= rate
        @oscs.each { |o| o.srate = rate }
      end
    end

    class Snare < DSP::Generator
      def initialize
        # Tonal component (Shell)
        @tone = DSP::Voice.new(
          osc: DSP::Tri,
          filter: DSP::ButterLP,
          amp_env: DSP::Env.perc(attack: 0.001, decay: 0.25),
          filter_env: DSP::Env.perc(attack: 0.001, decay: 0.1),
          filter_base: 150,
          filter_mod: 200,
          osc_base: 1.0,
          osc_mod: 50.0,
          osc_mod_target: :freq
        )
        
        # Noise component (Snares)
        @noise = DSP::Voice.new(
          osc: DSP::RpmNoise,
          filter: DSP::ButterHP,
          amp_env: DSP::Env.perc(attack: 0.001, decay: 0.3),
          filter_env: DSP::Env.perc(attack: 0.001, decay: 0.1),
          filter_base: 800, # High pass to remove rumble
          filter_mod: 0
        )
        @vca = SwingVCA.new
      end

      def play(note = 180) # Default snare fundamental freq
        @tone.play(note)
        @noise.play(1) # Frequency doesn't matter for noise
        self
      end

      def stop
        @tone.stop
        @noise.stop
      end

      # Required for generic mixing
      def tick
        # Mix tone and noise. Noise is usually louder in a snare.
        noise_sig = @noise.tick
        noise_sig = @vca.process(noise_sig)
        
        (@tone.tick * 0.5) + (noise_sig * 0.4)
      end
      
      def srate= rate
        @tone.srate = rate
        @noise.srate = rate
      end
    end

    class Cowbell < DSP::Generator
      def initialize
        # Authentic TR-808 Cowbell frequencies: ~540Hz and ~800Hz
        @freq1 = 540.0
        @freq2 = 800.0
        
        @osc1 = DSP::RpmSquare.new(@freq1)
        @osc2 = DSP::RpmSquare.new(@freq2)
        
        # Bandpass filter
        @bpf = DSP::ButterBP.new(700, q: 3.5)
        
        # Authentic 808 Cowbell envelope: sum of two decay envelopes
        @env1 = DSP::Env.perc(attack: 0.001, decay: 0.1) # Fast "poke"
        @env2 = DSP::Env.perc(attack: 0.001, decay: 0.5) # Longer ring
        
        @vca1 = SwingVCA.new
        @vca2 = SwingVCA.new
      end

      def play(note = nil)
        @env1.trigger!
        @env2.trigger!
        self
      end

      def stop
        @env1.gate_off!
        @env2.gate_off!
      end

      def tick
        sig1 = @vca1.process(@osc1.tick)
        sig2 = @vca2.process(@osc2.tick)
        
        # Sum the VCA outputs, then filter
        sig = sig1 + sig2
        sig = @bpf.tick(sig)
        
        # Sum of two decays
        sig * (@env1.tick * 0.7 + @env2.tick * 0.3)
      end

      def srate= rate
        @osc1.srate = rate
        @osc2.srate = rate
        @bpf.srate = rate
        @env1.srate = rate
        @env2.srate = rate
      end
    end

    class Cymbal < DSP::Generator
      def initialize
        @source = MetallicNoise.new
        
        # 808 Cymbal processing:
        # 1. Bandpass filter 1 (lower)
        # 2. Bandpass filter 2 (higher)
        # 3. Sum -> VCA
        
        # 808 Cymbal has a 'Body' path and a 'Sizzle' path
        @bpf_body   = DSP::ButterBP.new(3500, q: 2.5) # The "gong" part
        @bpf_sizzle = DSP::ButterBP.new(9000, q: 1.5) # The "air" part
        @hp         = DSP::ButterHP.new(4500)         # Final thinning
        
        @env  = DSP::Env.perc(attack: 0.005, decay: 1.8) 
        @vca  = SwingVCA.new
        @dc   = DSP::DCBlocker.new
      end

      def play(note = nil)
        @env.trigger!
        self
      end
      
      def stop; @env.gate_off!; end

      def tick
        raw = @source.tick
        
        # Parallel processing
        body = @bpf_body.tick(raw)
        sizzle = @bpf_sizzle.tick(raw)
        
        # Mix paths
        sig = (body * 0.45) + (sizzle * 0.55)
        
        # High pass after mixing and DC block
        sig = @hp.tick(@dc.tick(sig))
        
        # Swing VCA adds the grit
        sig = @vca.process(sig)
        sig * @env.tick * 3.5 
      end

      def srate= rate
        @source.srate = rate
        @bpf_body.srate = rate
        @bpf_sizzle.srate = rate
        @hp.srate = rate
        @env.srate = rate
        @dc.clear!
      end
    end

    class HiHat < DSP::Generator
      def initialize(decay: 0.05)
        @source = MetallicNoise.new
        @hp     = DSP::ButterHP.new(9500) # Very high HPF for typical 808 sizzle
        @env    = DSP::Env.perc(attack: 0.001, decay: decay)
        @vca    = SwingVCA.new
      end

      def play(note = nil)
        @env.trigger!
        # Reset VCA state for sharp attack
        @vca.instance_variable_get(:@dc_block).clear!
        self
      end

      def stop; @env.gate_off!; end

      def tick
        sig = @source.tick
        sig = @hp.tick(sig)

        sig = @vca.process(sig)

        sig * @env.tick * 3.0 # Boost hihat levels
      end

      def srate= rate
        @source.srate = rate
        @bpf.srate = rate
        @env.srate = rate
      end
    end

    class Kick808 < DSP::Generator
      def initialize
        @osc = DSP::TwinTOscillator.new(
          freq: 47.5,          # Tuned 808 Kick fundamental
          damping: 0.7,        # More sustain/bloom
          coupling: 1.0,
          drift: 0.005,
          drop: 1.02           # Extremely subtle natural drop
        )
        @lpf = DSP::ButterLP.new(120, q: 0.5) # Softening filter
      end

      def play(note = nil)
        if note
          target = DSP.to_freq(note)
          @osc.instance_variable_set(:@freq, target)
        end
        @osc.trigger!
        self
      end

      def stop
        # Twin-T naturally decays, no gate needed
      end

      def tick
        sig = @osc.tick
        @lpf.tick(sig) * 1.5 # Boost kick level
      end

      def srate= rate
        @osc.srate = rate
        @lpf.srate = rate
      end
    end

    class Tom808 < DSP::Generator
      def initialize(freq: 120) # Low: ~100, Mid: ~160, High: ~240
        @osc = DSP::TwinTOscillator.new(
          freq: freq,      
          damping: 1.5,        # Significantly shorter decay for toms
          coupling: 0.8,       
          drift: 0.01,
          drop: 1.03           
        )
        @lpf = DSP::ButterLP.new(freq * 2.0, q: 0.5)
        
        # "Poof of filtered noise" for 808 Toms
        @noise = DSP::Voice.new(
          osc: DSP::RpmNoise,
          filter: DSP::ButterBP,
          amp_env: DSP::Env.perc(attack: 0.01, decay: 0.1),
          filter_base: freq,
          filter_mod: 0
        )
        @vca = SwingVCA.new
      end

      def play(note = nil)
        if note
          freq = DSP.to_freq(note)
          @osc.instance_variable_set(:@freq, freq)
          @lpf.freq = freq * 1.5
        end
        @osc.trigger!
        @noise.play(1)
        self
      end

      def stop; end

      def tick
        # Tom body
        body = @lpf.tick(@osc.tick)
        
        # Noise "poof" through Swing VCA
        poof = @vca.process(@noise.tick)
        
        (body * 1.0) + (poof * 0.2)
      end

      def srate= rate
        @osc.srate = rate
        @lpf.srate = rate
        @noise.srate = rate
      end
    end

    class Clap808 < DSP::Generator
      def initialize
        @noise = DSP::RpmNoise.new
        @bpf = DSP::ButterBP.new(1000, q: 1.0) # Broad bandpass
        @hpf = DSP::ButterHP.new(800)          # Tone shaping
        
        # 808 Clap has 4 short attack pulses (the "slap") and a tail
        @slap_envs = 3.times.map { |i| DSP::Env.perc(attack: 0.005, decay: 0.01) }
        @tail_env  = DSP::Env.perc(attack: 0.01, decay: 0.3)
        @vca = SwingVCA.new
        @time = 0.0
      end

      def play(note = nil)
        @slap_envs.each { |e| e.trigger! }
        @tail_env.trigger!
        @time = 0.0
        self
      end

      def stop; end

      def tick
        noise_sig = @noise.tick
        
        # The multi-pulse envelope logic
        # Pulses are offset by ~8-12ms in hardware
        env_sig = 0.0
        env_sig += @slap_envs[0].tick if @time >= 0.0
        env_sig += @slap_envs[1].tick if @time >= 0.010
        env_sig += @slap_envs[2].tick if @time >= 0.020
        env_sig += @tail_env.tick if @time >= 0.030
        
        sig = @hpf.tick(@bpf.tick(noise_sig))
        sig = @vca.process(sig)
        
        @time += 1.0 / srate
        sig * env_sig * 1.5
      end

      def srate=(rate)
        @slap_envs.each { |e| e.srate = rate }
        @tail_env.srate = rate
        @bpf.srate = rate
        @hpf.srate = rate
      end
    end

    class Maraca808 < DSP::Generator
      def initialize
        @noise = DSP::RpmNoise.new
        @hpf = DSP::ButterHP.new(8000) # Very high HPF
        @env = DSP::Env.perc(attack: 0.001, decay: 0.05)
        @vca = SwingVCA.new
      end

      def play(note = nil)
        @env.trigger!
        self
      end

      def stop; end

      def tick
        sig = @noise.tick
        sig = @hpf.tick(sig)
        sig = @vca.process(sig)
        sig * @env.tick * 2.0
      end

      def srate=(rate)
        @hpf.srate = rate
        @env.srate = rate
      end
    end

    class DrumSynth
      def self.kick
        Kick808.new
      end

      def self.snare
        Snare.new
      end

      def self.hi_hat_closed
        HiHat.new(decay: 0.05)
      end

      def self.hi_hat_open
        HiHat.new(decay: 0.4)
      end

      def self.cymbal
        Cymbal.new
      end

      def self.tom(freq = 100)
        Tom808.new(freq: freq)
      end

      def self.cowbell
        Cowbell.new
      end

      def self.clap
        Clap808.new
      end

      def self.maraca
        Maraca808.new
      end
    end
  end
end
