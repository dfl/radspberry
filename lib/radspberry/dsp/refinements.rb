# Refinements for DSP extensions
#
# Instead of globally monkey-patching Array, Vector, and Module,
# you can use refinements for lexically-scoped extensions:
#
#   require 'radspberry/dsp/refinements'
#   using DSP::Refinements
#
#   # Now these work only in this file:
#   [1, 2, 3].to_v          # => Vector[1, 2, 3]
#   Vector.zeros(4)         # => Vector[0.0, 0.0, 0.0, 0.0]
#
# This avoids polluting the global namespace and makes dependencies explicit.

module DSP
  module Refinements
    # Array instance methods for DSP operations
    refine Array do
      def to_v
        Vector[*self]
      end

      def tick_sum(inp = 0.0)
        inject(inp) { |sum, p| sum + p.tick }
      end

      def ticks_sum(samples, inp = nil)
        inp ||= Vector.zeros(samples)
        inject(inp) { |sum, p| sum + p.ticks(samples) }
      end
    end

    # Array class methods
    refine Array.singleton_class do
      def full_of(val, count)
        [].fill(val, 0...count)
      end

      def zeros(count)
        full_of(0, count)
      end
    end

    # Vector class methods
    refine Vector.singleton_class do
      def full_of(val, count)
        Array.full_of(val, count).to_v
      end

      def zeros(count)
        full_of(0.0, count)
      end
    end

    # Module extensions for parameter accessors
    refine Module do
      def param_accessor(symbol, opts = {}, &block)
        opts = { range: opts } if opts.is_a?(Range)
        opts = { range: (0..1) }.merge(opts)
        var = nil

        if d = opts[:delegate]
          d = "@#{d}" if d.is_a?(Symbol)
          d = "#{d}.#{symbol}" unless d =~ /\./
          d, s = d.split(".")
          var = "#{d} && #{d}.#{s}"
        else
          var = symbol
          var = "@#{var}" if var.is_a?(Symbol)
        end

        # Define getter
        if opts[:default]
          module_eval "def #{symbol}() #{var} || #{opts[:default]}; end"
        else
          module_eval "def #{symbol}() #{var}; end"
        end

        # Define setter with optional range clamping
        if opts[:range]
          min, max = opts[:range].first.to_f, opts[:range].last.to_f
          module_eval <<-RUBY
            def #{symbol}=(val)
              #{var} = DSP.clamp(val, #{min}, #{max})
              #{"after_set_#{symbol}" if opts[:after_set]}
            end
          RUBY
          define_method "after_set_#{symbol}", opts[:after_set] if opts[:after_set]
        else
          module_eval "def #{symbol}=(val) #{var} = val; end"
        end
      end
    end
  end
end
