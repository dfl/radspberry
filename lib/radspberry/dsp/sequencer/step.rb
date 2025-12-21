# Step sequencer - cycles through a pattern

module DSP
  class StepSequencer < Generator
    attr_accessor :pattern, :step_duration, :looping

    def initialize(pattern: [60, 62, 64, 65], step_duration: 0.25, looping: true)
      @pattern = pattern
      @step_duration = step_duration
      @looping = looping
      reset!
    end

    def reset!
      @current_step = 0
      @current_note = @pattern.first
      @sample_in_step = 0
      @samples_per_step = (@step_duration * srate).to_i
      @gate_samples = (@samples_per_step * 0.8).to_i
      @done = false
    end

    def current_note
      @current_note
    end

    def current_freq
      midi_to_freq(@current_note)
    end

    def tick
      return 0.0 if @done

      gate = @sample_in_step < @gate_samples ? 1.0 : 0.0

      @sample_in_step += 1

      if @sample_in_step >= @samples_per_step
        @sample_in_step = 0
        @current_step += 1

        if @current_step >= @pattern.size
          if @looping
            @current_step = 0
          else
            @done = true
            return 0.0
          end
        end

        @current_note = @pattern[@current_step]
      end

      gate
    end

    private

    def midi_to_freq(note)
      440.0 * (2.0 ** ((note - 69) / 12.0))
    end
  end
end
