module DSP
  module Conversions
    extend self
    
    # Convert various note formats to frequency
    def to_freq(note = nil, midi: nil)
      return midi_to_freq(midi) if midi && note.nil?
      return Note.freq(note) if note.is_a?(Symbol)

      note.to_f
    end

    # Convert MIDI number to frequency
    def midi_to_freq(midi)
      Note.midi_to_freq(midi)
    end

    # Convert various note formats to MIDI
    def to_midi(note)
      case note
      when Symbol then Note.midi(note)
      when Integer then note
      when Float then (69 + 12 * Math.log2(note / Note::A4_FREQ)).round
      else raise ArgumentError, "Can't convert #{note.class} to MIDI"
      end
    end
  end
  
  # Expose module methods directly on DSP module
  class << self
    include Conversions
  end
end
