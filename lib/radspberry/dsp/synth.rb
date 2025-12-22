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
          if @chain.respond_to?(:broadcast_param)
            @chain.broadcast_param(k, v)
          elsif @chain.respond_to?("#{k}=")
            @chain.send("#{k}=", v)
          end
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
      
      # Delegate play to Speaker
      def play(duration = nil)
        # Auto-trigger envelopes if they are in idle state
        if @chain.respond_to?(:trigger!)
           @chain.trigger!
        elsif @chain.is_a?(GeneratorChain)
           # We need a way to broadcast trigger! 
           # We can rely on a broadcast method or manual iteration
           # Let's add broadcast_trigger to Base or just iterate here for safety.
           # But wait, GeneratorChain usually wraps a ProcessorChain.
           # Let's try use broadcast_param-like logic but for methods.
           broadcast_method(:trigger!)
        end
        
        Speaker.play(self)
        if duration
          sleep duration
          Speaker.stop
        end
        self
      end

      def broadcast_method(method, *args)
        if @chain.respond_to?(:broadcast_method)
          @chain.broadcast_method(method, *args) 
        elsif @chain.respond_to?(method)
          @chain.send(method, *args)
        end
      end
    end
  end
end
