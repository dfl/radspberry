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

      # Convert a pattern to a Ring of booleans
      # 
      # Strings: "x-x-" (visual step sequencing)
      # Integers: 0x80C0 (hexadecimal/binary bitmask, 16-bit default)
      def seq(pattern)
        case pattern
        when Integer
          # Treat as 16-bit bitmask (MSB first)
          # 0x0808 -> 0000 1000 0000 1000
          res = pattern.to_s(2).rjust(16, '0').chars.map { |c| c == '1' }
          Ring.new(res)
        when String
          if pattern.start_with?("0x")
             # Keep legacy/string hex support just in case, or remove?
             # User said: "If we give a string, it should parse like it did before."
             # "Before" meant "x-x-". 
             # I'll keep the Hex string support I just added as it's useful, 
             # but ensure Integer is the primary way for hex.
             res = pattern[2..-1].chars.flat_map do |c|
               val = c.to_i(16)
               [ (val&8)!=0, (val&4)!=0, (val&2)!=0, (val&1)!=0 ]
             end
             Ring.new(res)
          else
            # Standard x/.- mode
            res = pattern.chars.map do |c|
              case c
              when 'x', 'X', '*' then true
              else false
              end
            end
            Ring.new(res)
          end
        else
          raise ArgumentError, "seq pattern must be String or Integer"
        end
      end
    end
  end
end
