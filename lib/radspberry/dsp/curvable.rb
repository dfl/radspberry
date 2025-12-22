module DSP
  module Curvable
    attr_accessor :curve

    def apply_curve(value, direction)
      # @curve should be set by the including class
      case @curve
      when :linear then value
      when :exponential
        direction == :up ? value * value : ::Math.sqrt(value)
      when :logarithmic
        direction == :up ? ::Math.sqrt(value) : value * value
      else value
      end
    end
  end
end
