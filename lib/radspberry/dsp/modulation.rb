# Modulation wrapper - declarative parameter modulation
#
# Usage:
#   filter = ButterLP.new(1000)
#   lfo = Phasor.new(5)
#
#   # Wrap with modulation
#   filter.modulate(:freq, lfo, range: 200..4000)
#   # or with block:
#   filter.modulate(:freq, lfo) { |v| 200 + v * 3800 }
#
#   # Chain multiple:
#   filter.modulate(:freq, lfo1, range: 200..4000)
#         .modulate(:q, lfo2, range: 0.5..10)
#
#   # Now just tick - modulation happens automatically
#   output = filter.tick(input)

require 'delegate'

module DSP
  class ModulatedProcessor < SimpleDelegator
    def initialize(processor)
      super(processor)
      @modulations = {}
    end

    def tick(*args)
      apply_modulations
      # Support both Generator (0 args) and Processor (1 arg)
      __getobj__.tick(*args)
    end

    def ticks(inputs_or_samples)
      if inputs_or_samples.is_a?(Numeric)
        # Handle Generator behavior
        inputs_or_samples.times.map { tick }.to_v
      else
        # Handle Processor behavior
        inputs_or_samples.map { |s| tick(s) }
      end
    end

    def modulate(param, source, range: nil, &block)
      transform = if block
        block
      elsif range
        min, max = range.begin.to_f, range.end.to_f
        ->(v) { min + v * (max - min) }
      else
        ->(v) { v }
      end

      @modulations[param] = { source: source, transform: transform }
      self
    end

    def unmodulate(param)
      @modulations.delete(param)
      self
    end

    def clear_modulations
      @modulations.clear
      self
    end

    def modulated_params
      @modulations.keys
    end

    private

    def apply_modulations
      @modulations.each do |param, mod|
        value = mod[:source].tick
        transformed = mod[:transform].call(value)
        __getobj__.send("#{param}=", transformed)
      end
    end
  end

  # Add modulate method to both Generator and Processor
  [Generator, Processor].each do |klass|
    klass.class_eval do
      def modulate(param, source, range: nil, &block)
        ModulatedProcessor.new(self).modulate(param, source, range: range, &block)
      end
    end
  end
end
