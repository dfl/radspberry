# Amplitude envelope - wraps a generator and applies envelope

module DSP
  class AmpEnvelope < Generator
    attr_reader :envelope, :source

    def initialize(source, envelope)
      @source = source
      @envelope = envelope
    end

    def tick
      @source.tick * @envelope.tick
    end

    def ticks(samples)
      src = @source.ticks(samples).to_a
      env = @envelope.ticks(samples).to_a
      src.zip(env).map { |s, e| s * e }.to_v
    end

    def trigger!
      @envelope.trigger!
    end

    def gate_on!
      @envelope.gate_on! if @envelope.respond_to?(:gate_on!)
    end

    def gate_off!
      @envelope.gate_off! if @envelope.respond_to?(:gate_off!)
    end

    def method_missing(method, *args, &block)
      if @source.respond_to?(method)
        @source.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @source.respond_to?(method, include_private) || super
    end
  end


  class FilterEnvelope < Processor
    attr_reader :envelope, :filter
    attr_accessor :base_freq, :mod_range

    def initialize(filter, envelope, base_freq: 200, mod_range: 4000)
      @filter = filter
      @envelope = envelope
      @base_freq = base_freq
      @mod_range = mod_range
    end

    def tick(input)
      env_val = @envelope.tick
      @filter.freq = @base_freq + env_val * @mod_range
      @filter.tick(input)
    end

    def ticks(inputs)
      inputs.map { |s| tick(s) }
    end

    def trigger!
      @envelope.trigger!
    end

    def gate_on!
      @envelope.gate_on! if @envelope.respond_to?(:gate_on!)
    end

    def gate_off!
      @envelope.gate_off! if @envelope.respond_to?(:gate_off!)
    end
  end

  module Amp
    def self.[](envelope)
      # returns a processor that applies the envelope
      # In this system, AmpEnvelope is a Generator that wraps another Generator.
      # But the user wants something they can chain: osc >> filt >> Amp[env]
      # So we need a Processor that takes an input and multiplies by env.
      AmpProcessor.new(envelope)
    end
  end

  class AmpProcessor < Processor
    def initialize(envelope)
      @envelope = envelope
    end
    def tick(input)
      input * @envelope.tick
    end
    def ticks(inputs)
      env_vals = @envelope.ticks(inputs.size)
      inputs.to_v.zip(env_vals).map { |s, e| s * e }.to_v
    end
    def method_missing(m, *a, &b)
      @envelope.respond_to?(m) ? @envelope.send(m, *a, &b) : super
    end
    def respond_to_missing?(m, i = false)
      @envelope.respond_to?(m, i) || super
    end
  end

  module Filt
    def self.[](params)
      # filt = Filt[cutoff: 1000, res: 0.7] >> Amp[env]
      # This is tricky because it needs to be a Processor.
      # For now, let's keep it simple or see how users want to use it.
    end
  end
end
