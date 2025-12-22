module DSP
  class Synth < Generator
    @@definitions = {}

    def self.define(name, &block)
      @@definitions[name] = block
    end

    def self.[](name, **params)
      definition = @@definitions[name]
      raise ArgumentError, "Synth #{name} not defined" unless definition
      SynthInstance.new(definition, **params)
    end

    class SynthInstance < Generator
      attr_reader :chain, :params

      def initialize(definition, **params)
        @definition = definition
        @params = params
        rebuild!
      end

      def rebuild!
        # Capture the current params for the block
        # The block should return a Generator (or something that responds to tick)
        @chain = @definition.call(**@params)
      end

      def set(**new_params)
        @params.merge!(new_params)
        new_params.each do |k, v|
          @chain.broadcast_param(k, v)
        end
        self
      end

      def tick
        @chain.tick
      end

      def ticks(samples)
        @chain.ticks(samples)
      end

      def srate=(rate)
        super
        @chain.srate = rate if @chain.respond_to?(:srate=)
      end
    end
  end
end
