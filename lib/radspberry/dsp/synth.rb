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

      def broadcast_param(key, value)
        @chain.broadcast_param(key, value)
      end

      def broadcast_method(method, *args)
        @chain.broadcast_method(method, *args)
      end

      # Play a sequence of notes and rests
      # duration: duration per step
      # This version is sample-accurate (no sleep/jitter)
      def play_pattern(pattern, duration: 0.25)
        seq = PatternSequencer.new(self, pattern, duration: duration)
        Speaker.play(seq)
        seq # Return sequencer so user can call .wait
      end

      # Render a pattern to a wave file (offline, non-real-time)
      # This allows precise timing verification
      def render_pattern(pattern, filename: "pattern_verification.wav", duration: 0.25)
        steps = Pattern[pattern].elements
        total_seconds = steps.size * duration
        total_samples = (total_seconds * srate).to_i
        samples_per_step = (duration * srate).to_i
        
        output = Vector.zeros(total_samples)
        
        steps.each_with_index do |note, i|
          if note != :r
            # Update frequency and trigger the note
            set(freq: note)
            broadcast_method(:trigger!)
            
            # Record starting from this step
            start_sample = i * samples_per_step
            # We render a chunk and ADD it to the output to handle overlapping envelopes
            # For simplicity in verification, we'll just render it into the space
            chunk = ticks(samples_per_step)
            chunk.each_with_index do |val, j|
              output[start_sample + j] = val
            end
          end
        end
        
        # Save output to wav using existing to_wav on a dummy generator
        # Or just use the data directly. Base#to_wav takes seconds.
        # Let's use a helper or just write it.
        # Actually, let's just use the logic from Base#to_wav
        
        data = output.to_a
        rescale = calc_sample_value(-0.5, 16) / [data.map(&:abs).max, 1e-6].max
        data.map!{|d| (d*rescale).round.to_i }
        
        format = WaveFile::Format.new(:mono, :pcm_16, srate.to_i)
        buffer = WaveFile::Buffer.new(data, format)
        WaveFile::Writer.new(filename, format) { |w| w.write(buffer) }
        
        puts "   Rendered to #{filename}"
        filename
      end
    end
  end
end
