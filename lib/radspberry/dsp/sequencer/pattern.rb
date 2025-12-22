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
        result = []
        pattern.split(/\s+/).each do |token|
          # Scan for note names, rests, or ~ marks
          parts = token.scan(/([a-g][sb]?-?\d+|[r\.~])/i).flatten
          
          parts.each_with_index do |part, i|
            case part
            when "~"
              # If the NEXT part is a note, it will be handled by the next iteration
              # If THERE IS NO next part, or next part is another ~, it's a tie
              next_part = parts[i+1]
              if next_part && next_part.match?(/[a-g][sb]?-?\d/i)
                # Next note will be legato (will be handled by note branch)
              else
                result << :tie
              end
            when ".", "r", "R"
              result << :r
            when /[a-g][sb]?-?\d/i
              # Is the PREVIOUS part a ~?
              if i > 0 && parts[i-1] == "~"
                result << [:legato, part.to_sym]
              else
                result << part.to_sym
              end
            end
          end
        end
        result
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

  class PatternSequencer < Generator
    attr_reader :synth, :pattern, :step_duration

    def initialize(synth, pattern, duration: 0.25)
      @synth = synth
      @pattern = Pattern[pattern].elements
      @step_duration = duration
      reset!
    end

    def reset!
      @current_step = 0
      @samples_per_step = (@step_duration * srate).to_i
      @sample_in_step = 0
      @done = false
    end

    def tick
      return 0.0 if @done

      if @sample_in_step == 0
        note = @pattern[@current_step]
        if note == :r
          # Optional: gate_off! ?
        elsif note.is_a?(Array) && note[0] == :legato
          @synth.set(freq: note[1])
          # NO trigger!
        elsif note != :tie
          @synth.set(freq: note)
          @synth.broadcast_method(:trigger!)
        end
      end

      out = @synth.tick
      @sample_in_step += 1

      if @sample_in_step >= @samples_per_step
        @sample_in_step = 0
        @current_step += 1
        if @current_step >= @pattern.size
          @done = true
        end
      end

      out
    end

    def ticks(samples)
      samples.times.map { tick }.to_v
    end

    def alive?
      !@done
    end

    def wait
      sleep 0.1 while alive?
      self
    end
  end
end
