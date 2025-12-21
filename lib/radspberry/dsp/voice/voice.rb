# Voice - combines oscillator + filter + amp envelope

module DSP
  class Voice < Generator
    attr_reader :osc, :filter, :amp_env, :filter_env
    attr_accessor :filter_base, :filter_mod

    def initialize(osc: SuperSaw, filter: ButterLP, amp_env: nil, filter_env: nil,
                   filter_base: 200, filter_mod: 4000, &block)
      @osc = osc.is_a?(Class) ? osc.new : osc
      @filter = filter.is_a?(Class) ? filter.new(1000) : filter
      @amp_env = amp_env || Env.adsr
      @filter_env = filter_env || Env.perc
      @filter_base = filter_base
      @filter_mod = filter_mod

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

    def cutoff
      @filter.freq
    end

    def cutoff=(f)
      @filter_base = DSP.to_freq(f)
    end

    def tick
      env_val = @filter_env.tick
      @filter.freq = @filter_base + env_val * @filter_mod

      sample = @osc.tick
      sample = @filter.tick(sample)
      sample * @amp_env.tick
    end

    def ticks(samples)
      samples.times.map { tick }.to_v
    end
  end
end
