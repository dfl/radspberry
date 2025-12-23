require_relative 'dsl/ring'
require_relative 'dsl/patterns'

module DSP
  module DSL
    include State
    include Patterns

    # Extension methods for Array and Ring
    module Extensions
      def ring
        Ring.new(self)
      end

      def tick(name = :default)
        self[DSL.tick(name)]
      end

      def look(name = :default)
        self[DSL.look(name)]
      end

      def choose
        sample
      end
    end
  end
end

# Add to Array
Array.send :include, DSP::DSL::Extensions

# Add to the global namespace for easy DSL usage
# (Optional, but user asked for Sonic Pi borrow, where these are global)
module Kernel
  include DSP::DSL::State
  include DSP::DSL::Patterns
  
  def ring(*args)
    DSP::DSL::Ring.new(args)
  end
end
