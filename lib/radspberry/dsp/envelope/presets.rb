# Convenience constructors for common envelope shapes

module DSP
  module Env
    extend self

    def perc(attack: 0.005, decay: 0.2)
      AnalogADEnvelope.new(attack: attack, decay: decay)
    end

    def pluck(attack: 0.001, decay: 0.1)
      AnalogADEnvelope.new(attack: attack, decay: decay)
    end

    def pad(attack: 0.5, decay: 0.3, sustain: 0.7, release: 0.8)
      AnalogEnvelope.new(attack: attack, decay: decay, sustain: sustain, release: release)
    end

    def adsr(attack: 0.01, decay: 0.1, sustain: 0.7, release: 0.3)
      AnalogEnvelope.new(attack: attack, decay: decay, sustain: sustain, release: release)
    end

    def ad(attack: 0.01, decay: 0.2)
      AnalogADEnvelope.new(attack: attack, decay: decay)
    end

    def swell(attack: 1.0, decay: 0.5, sustain: 0.8, release: 0.5)
      AnalogEnvelope.new(attack: attack, decay: decay, sustain: sustain, release: release)
    end

    def gate
      AnalogEnvelope.new(attack: 0.001, decay: 0.001, sustain: 1.0, release: 0.001)
    end
  end
end
