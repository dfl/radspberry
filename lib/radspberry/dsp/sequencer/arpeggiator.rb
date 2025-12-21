# Arpeggiator - cycles through held notes

module DSP
  class Arpeggiator < Generator
    MODES = [:up, :down, :up_down, :random]

    attr_accessor :notes, :step_duration, :octaves, :mode

    def initialize(notes: [60, 64, 67], step_duration: 0.125, octaves: 1, mode: :up)
      @notes = notes.sort
      @step_duration = step_duration
      @octaves = octaves
      @mode = mode
      reset!
    end

    def reset!
      @arp_sequence = build_arp_sequence
      @current_index = 0
      @current_note = @arp_sequence.first || @notes.first
      @sample_in_step = 0
      @samples_per_step = (@step_duration * srate).to_i
      @gate_samples = (@samples_per_step * 0.8).to_i
    end

    def note_on(note)
      @notes << note unless @notes.include?(note)
      @notes.sort!
      reset!
    end

    def note_off(note)
      @notes.delete(note)
      reset! if @notes.any?
    end

    def current_note
      @current_note
    end

    def current_freq
      midi_to_freq(@current_note)
    end

    def tick
      return 0.0 if @notes.empty? || @arp_sequence.empty?

      gate = @sample_in_step < @gate_samples ? 1.0 : 0.0

      @sample_in_step += 1

      if @sample_in_step >= @samples_per_step
        @sample_in_step = 0
        @current_index += 1

        if @current_index >= @arp_sequence.size
          @current_index = 0
          @arp_sequence = build_arp_sequence if @mode == :random
        end

        @current_note = @arp_sequence[@current_index]
      end

      gate
    end

    private

    def build_arp_sequence
      return [] if @notes.empty?

      expanded = []
      @octaves.times do |oct|
        @notes.each { |n| expanded << n + (oct * 12) }
      end

      case @mode
      when :up then expanded
      when :down then expanded.reverse
      when :up_down
        return expanded if expanded.size <= 2
        expanded + expanded.reverse[1..-2]
      when :random then expanded.shuffle
      else expanded
      end
    end

    def midi_to_freq(note)
      440.0 * (2.0 ** ((note - 69) / 12.0))
    end
  end
end
