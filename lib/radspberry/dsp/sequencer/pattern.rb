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
        if note != :r
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
