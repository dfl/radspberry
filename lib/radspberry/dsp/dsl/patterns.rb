module DSP
  module DSL
    module State
      def tick(name = :default)
        Thread.current[:radspberry_ticks] ||= Hash.new(-1)
        Thread.current[:radspberry_ticks][name] += 1
      end

      def look(name = :default)
        Thread.current[:radspberry_ticks] ||= Hash.new(-1)
        val = Thread.current[:radspberry_ticks][name]
        val == -1 ? 0 : val
      end

      def reset_tick(name = :default)
        Thread.current[:radspberry_ticks] ||= Hash.new(-1)
        Thread.current[:radspberry_ticks][name] = -1
      end
    end

    module Patterns
      def spread(on, total, rotate: 0)
        return Ring.new([false] * total) if on <= 0
        return Ring.new([true] * total) if on >= total
        
        res = Array.new(total) { |i| ((i * on) / total.to_f).floor > (((i - 1) * on) / total.to_f).floor }
        
        res = res.rotate(-rotate) if rotate != 0
        Ring.new(res)
      end

      def knit(*args)
        res = []
        args.each_slice(2) do |val, count|
          count.times { res << val }
        end
        Ring.new(res)
      end

      def choose(array)
        array.sample
      end

      def one_in(n)
        rand(n) == 0
      end
      
      def dice(n = 6)
        rand(1..n)
      end
    end
  end
end
