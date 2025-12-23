module DSP
  module DSL
    module Samples
      def self.included(base)
        @sample_cache = {}
      end

      def self.sample_cache
        @sample_cache ||= {}
      end

      def sample(path_or_symbol, opts = {})
        path = path_or_symbol.to_s
        
        # If it's a symbol like :kick, look in a default location
        if path_or_symbol.is_a?(Symbol)
          # Try to find in ./samples/ or lib/radspberry/samples/
          possible_paths = [
            "samples/#{path}.wav",
            File.expand_path("../../../samples/#{path}.wav", __FILE__)
          ]
          path = possible_paths.find { |p| File.exist?(p) } || path
        end

        sampler = DSL::Samples.sample_cache[path] ||= Sampler.new(path)
        
        # Copy settings to a new instance or reuse? 
        # Usually we want a new instance if we want to play multiple at once
        # but Sampler is a Generator, so we can just return a new one sharing the buffer.
        inst = Sampler.new
        inst.instance_variable_set(:@buffer, sampler.buffer)
        inst.instance_variable_set(:@rate_compensation, sampler.instance_variable_get(:@rate_compensation))
        inst.rate = opts[:rate] || 1.0
        inst.volume = opts[:volume] || opts[:amp] || 1.0
        inst.loop = opts[:loop] || false
        inst.trigger!
        
        # Add to the global rhythmic mixer for additive playback
        DSP.sampler_mixer.add(inst)
        
        # Start the mixer if it hasn't been started, but be careful not to 
        # replace a running synth that isn't our mixer.
        # However, for Sonic Pi DSL, we often want both.
        # For now, let's just make sure the mixer is available.
        unless Speaker.playing? && Speaker.synth.is_a?(DynamicMixer)
          # We might want to + with current synth, but that's complex.
          # For a spike, we'll just play the mixer.
          # Speaker.play(DSP.sampler_mixer) 
        end
        
        inst
      end
    end
  end
end
