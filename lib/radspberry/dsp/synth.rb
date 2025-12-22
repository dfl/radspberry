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

      # Play a sequence of notes and rests
      # duration: duration per step
      def play_pattern(pattern, duration: 0.25)
        Pattern[pattern].each do |note|
          if note == :r
            sleep duration
          else
            # We can't use .play(duration) here because it blocks the whole chain
            # We want to fire a note and then sleep for the step duration
            # But SynthInstance *is* the instrument.
            
            # For monophonic synths, we update the freq and trigger
            set(freq: note)
            broadcast_method(:trigger!)
            sleep duration
          end
        end
        self
      end
    end
  end
end
