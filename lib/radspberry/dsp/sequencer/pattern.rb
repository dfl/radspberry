# Pattern helper for sequencing notes and rests
module DSP
  class Pattern
    attr_reader :elements

    def initialize(pattern)
      @elements = parse(pattern)
    end

    def self.[](pattern)
      new(pattern)
    end

    def each
      return to_enum(:each) unless block_given?
      @elements.each { |e| yield e }
    end

    private

    def parse(pattern)
      case pattern
      when String
        # Split by whitespace, support '.' or '~' as rests
        pattern.split(/\s+/).map do |s|
          if s == '.' || s == '~' || s.downcase == 'r'
            :r
          else
            s.to_sym
          end
        end
      when Array
        pattern.map { |e| rest?(e) ? :r : e }
      else
        [pattern]
      end
    end

    def rest?(e)
      e == :r || e == :rest || e.nil?
    end
  end
end
