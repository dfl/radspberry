module DSP
  module DSL
    class Ring < Array
      def [](index)
        return nil if empty?
        super(index % size)
      end

      # Transformation methods that return a new Ring
      def shuffle
        Ring.new(super)
      end

      def reverse
        Ring.new(super)
      end

      def rotate(n = 1)
        Ring.new(super(n))
      end

      def mirror
        Ring.new(self + self.reverse)
      end

      def reflect # same as mirror in Sonic Pi often? Actually mirror is often used.
        Ring.new(self + self.reverse[1..-2])
      end

      def stretch(n)
        Ring.new(flat_map { |x| [x] * n })
      end

      def repeat(n)
        Ring.new(super(n)) rescue Ring.new(self * n)
      end
      
      def inspect
        "(ring #{join(', ')})"
      end
    end
  end
end
