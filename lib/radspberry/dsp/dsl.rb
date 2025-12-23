require_relative 'dsl/ring'
require_relative 'dsl/patterns'
require_relative 'dsl/live_loop'
require_relative 'dsl/samples'

module DSP
  module DSL
    include State
    include Patterns
    include LiveLoop
    include Samples

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
  include DSP::DSL::LiveLoop
  include DSP::DSL::Samples
  
  def ring(*args)
    DSP::DSL::Ring.new(args)
  end
end
