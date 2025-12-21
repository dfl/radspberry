module DSP
  module Curvable
    attr_accessor :curve

    def apply_curve(value, direction)
      # @curve should be set by the including class
      case @curve
      when :linear then value
      when :exponential
        direction == :up ? value ** 2 : value ** 0.5
      when :logarithmic
        direction == :up ? value ** 0.5 : value ** 2
      else value
      end
    end
  end
end
