# Voice - combines oscillator + filter + amp envelope

module DSP
  class Voice < Generator
    attr_accessor :osc, :filter, :amp_env, :filter_env, :filter_base, :filter_mod, :osc_base, :osc_mod, :osc_mod_target
    alias_method :mod_env, :filter_env
    alias_method :sync_env, :filter_env

    def initialize(osc: SuperSaw, filter: ButterLP, amp_env: nil, filter_env: nil,
                   filter_base: 200, filter_mod: 4000,
                   osc_base: 0.0, osc_mod: 0.0, osc_mod_target: nil, &block)
      @osc = osc.is_a?(Class) ? osc.new : osc
      @filter = filter.is_a?(Class) ? filter.new(1000) : filter
      @amp_env = amp_env || Env.adsr
      @filter_env = filter_env || Env.perc
      @filter_base = filter_base
      @filter_mod = filter_mod
      @osc_base = osc_base
      @osc_mod = osc_mod
      @osc_mod_target = osc_mod_target

      block.call(self) if block
    end

    # Presets
    def self.acid(note = nil)
      v = new(
        osc: RpmSaw,
        filter: ButterLP,
        amp_env: Env.adsr(attack: 0.005, decay: 0.1, sustain: 0.0, release: 0.05),
        filter_env: Env.perc(attack: 0.001, decay: 0.15),
        filter_base: 250,
        filter_mod: 3500
      )
      v.play(note) if note
      v
    end

    def self.pad(note = nil)
      v = new(
        osc: SuperSaw,
        filter: ButterLP,
        amp_env: Env.pad,
        filter_env: Env.ad(attack: 0.5, decay: 1.0),
        filter_base: 300,
        filter_mod: 2000
      )
      v.play(note) if note
      v
    end

    def self.pluck(note = nil)
      v = new(
        osc: RpmSquare,
        filter: ButterLP,
        amp_env: Env.adsr(attack: 0.002, decay: 0.15, sustain: 0.3, release: 0.1),
        filter_env: Env.pluck,
        filter_base: 400,
        filter_mod: 5000
      )
      v.play(note) if note
      v
    end

    def self.lead(note = nil)
      v = new(
        osc: RpmSaw,
        filter: ButterLP,
        amp_env: Env.adsr(attack: 0.01, decay: 0.2, sustain: 0.6, release: 0.2),
        filter_env: Env.ad(attack: 0.01, decay: 0.3),
        filter_base: 500,
        filter_mod: 3000
      )
      v.play(note) if note
      v
    end

    def self.sync(note = nil)
      v = new(
        osc: DualRPMOscillator,
        filter: ButterLP,
        amp_env: Env.adsr(attack: 0.005, decay: 0.3, sustain: 0.5, release: 0.2),
        filter_env: Env.perc(attack: 0.01, decay: 4.0), # used for ratio sweep
        filter_base: 1000,
        filter_mod: 8000,
        osc_base: 1.0,
        osc_mod: 7.0,
        osc_mod_target: :sync_ratio
      )
      v.play(note) if note
      v
    end

    def freq=(f)
      @freq = DSP.to_freq(f)
      @osc.freq = @freq if @osc.respond_to?(:freq=)
    end

    def freq
      @freq
    end

    def play(note)
      note_on(note)
    end

    def stop
      note_off
    end

    def note_on(note)
      self.freq = note
      @amp_env.gate_on!
      @filter_env.trigger!
    end

    def note_off
      @amp_env.gate_off!
    end

    # Parameter aliases for cleaner API
    def cutoff
      @filter_base
    end

    def cutoff=(f)
      @filter_base = DSP.to_freq(f)
    end

    def resonance
      @filter.q
    end

    def resonance=(r)
      @filter.q = r
    end
    alias_method :res, :resonance
    alias_method :res=, :resonance=

    def attack
      @amp_env.attack
    end

    def attack=(t)
      @amp_env.attack = t
    end

    def decay
      @amp_env.decay
    end

    def decay=(t)
      @amp_env.decay = t
    end

    def sustain
      @amp_env.sustain
    end

    def sustain=(l)
      @amp_env.sustain = l
    end

    def release
      @amp_env.release
    end

    def release=(t)
      @amp_env.release = t
    end

    # Bulk parameter update
    def set(**params)
      params.each { |k, v| send("#{k}=", v) }
      self
    end

    def tick
      env_val = @filter_env.tick
      @filter.freq = @filter_base + env_val * @filter_mod

      if @osc_mod_target && @osc.respond_to?("#{@osc_mod_target}=")
        @osc.send("#{@osc_mod_target}=", @osc_base + env_val * @osc_mod)
      end

      sample = @osc.tick
      sample = @filter.tick(sample)
      sample * @amp_env.tick
    end

    def ticks(samples)
      samples.times.map { tick }.to_v
    end
  end
end
