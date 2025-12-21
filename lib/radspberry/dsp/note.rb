# Note/MIDI conversion helpers
# Enables :c3.midi, :c3.freq, :c3.major, etc.

module Note
  NOTE_NAMES = %w[c cs d ds e f fs g gs a as b].freeze
  NOTE_ALIASES = { 'db' => 'cs', 'eb' => 'ds', 'fb' => 'e', 'gb' => 'fs',
                   'ab' => 'gs', 'bb' => 'as', 'cb' => 'b' }.freeze

  CHORDS = {
    major:  [0, 4, 7],
    minor:  [0, 3, 7],
    major7: [0, 4, 7, 11],
    minor7: [0, 3, 7, 10],
    dom7:   [0, 4, 7, 10],
    dim:    [0, 3, 6],
    dim7:   [0, 3, 6, 9],
    aug:    [0, 4, 8],
    sus2:   [0, 2, 7],
    sus4:   [0, 5, 7],
    add9:   [0, 4, 7, 14],
  }.freeze

  A4_FREQ = 440.0
  A4_MIDI = 69

  extend self

  def parse(sym)
    str = sym.to_s.downcase
    match = str.match(/^([a-g][sb]?)(-?\d)$/)
    raise ArgumentError, "Invalid note: #{sym}" unless match

    note_name, octave = match[1], match[2].to_i
    note_name = NOTE_ALIASES[note_name] || note_name
    semitone = NOTE_NAMES.index(note_name)
    raise ArgumentError, "Invalid note name: #{note_name}" unless semitone

    (octave + 1) * 12 + semitone
  end

  def midi(sym)
    parse(sym)
  end

  def freq(sym)
    A4_FREQ * (2.0 ** ((midi(sym) - A4_MIDI) / 12.0))
  end

  def midi_to_sym(m)
    "#{NOTE_NAMES[m % 12]}#{(m / 12) - 1}".to_sym
  end

  def chord(sym, type)
    m = midi(sym)
    CHORDS[type].map { |i| midi_to_sym(m + i) }
  end

  def transpose(sym, semitones)
    midi_to_sym(midi(sym) + semitones)
  end
end


class Symbol
  def note?
    to_s.match?(/^[a-g][sb]?-?\d$/i)
  end

  def midi
    note? ? Note.midi(self) : super
  end

  def freq
    note? ? Note.freq(self) : super
  end

  def up(n = 12)
    note? ? Note.transpose(self, n) : super
  end

  def down(n = 12)
    note? ? Note.transpose(self, -n) : super
  end

  # Generate chord methods
  Note::CHORDS.each_key do |chord_type|
    define_method(chord_type) do
      note? ? Note.chord(self, chord_type) : super()
    end
  end

  # Transpose operators (Symbol doesn't have these by default)
  def +(other)
    raise NoMethodError, "undefined method `+' for #{self.inspect}" unless note?
    Note.transpose(self, other)
  end

  def -(other)
    raise NoMethodError, "undefined method `-' for #{self.inspect}" unless note?
    Note.transpose(self, -other)
  end
end


module DSP
  # Convert various note formats to frequency
  def self.to_freq(note)
    case note
    when Symbol then Note.freq(note)
    when Integer then note < 128 ? Note::A4_FREQ * (2.0 ** ((note - 69) / 12.0)) : note.to_f
    when Float then note
    else raise ArgumentError, "Can't convert #{note.class} to frequency"
    end
  end

  # Convert various note formats to MIDI
  def self.to_midi(note)
    case note
    when Symbol then Note.midi(note)
    when Integer then note
    when Float then (69 + 12 * Math.log2(note / Note::A4_FREQ)).round
    else raise ArgumentError, "Can't convert #{note.class} to MIDI"
    end
  end
end
