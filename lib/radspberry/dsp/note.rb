# Note/MIDI conversion helpers
# Enables :c3.midi, :c3.freq, :c3.major, etc.

module NoteSymbolExtensions
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

  def midi
    parse_note[:midi]
  end

  def freq
    A4_FREQ * (2.0 ** ((midi - A4_MIDI) / 12.0))
  end

  def parse_note
    str = to_s.downcase
    match = str.match(/^([a-g][sb]?)(-?\d)$/)
    raise ArgumentError, "Invalid note: #{self}" unless match

    note_name, octave = match[1], match[2].to_i
    note_name = NOTE_ALIASES[note_name] || note_name
    semitone = NOTE_NAMES.index(note_name)
    raise ArgumentError, "Invalid note name: #{note_name}" unless semitone

    { midi: (octave + 1) * 12 + semitone, name: note_name, octave: octave }
  end

  # Generate chord methods from CHORDS hash
  CHORDS.each do |name, intervals|
    define_method(name) do
      m = midi
      intervals.map { |i| midi_to_note(m + i) }
    end
  end

  # Transpose: :c3 + 7 => :g3
  def +(semitones)  = midi_to_note(midi + semitones)
  def -(semitones)  = midi_to_note(midi - semitones)
  def up(n = 12)    = self + n
  def down(n = 12)  = self - n

  private

  def midi_to_note(m)
    "#{NOTE_NAMES[m % 12]}#{(m / 12) - 1}".to_sym
  end
end


class Symbol
  NOTE_METHODS = [:midi, :freq, :up, :down, :+, :-] + NoteSymbolExtensions::CHORDS.keys

  def note?
    to_s.match?(/^[a-g][sb]?-?\d$/i)
  end

  NOTE_METHODS.each do |method|
    original = instance_method(method) rescue nil
    define_method(method) do |*args|
      if note?
        extend NoteSymbolExtensions
        send(method, *args)
      elsif original
        original.bind(self).call(*args)
      else
        super(*args)
      end
    end
  end
end


module DSP
  # Convert various note formats to frequency
  def self.to_freq(note)
    case note
    when Symbol then note.freq
    when Integer then note < 128 ? midi_to_freq(note) : note.to_f
    when Float then note
    else raise ArgumentError, "Can't convert #{note.class} to frequency"
    end
  end

  # Convert various note formats to MIDI
  def self.to_midi(note)
    case note
    when Symbol then note.midi
    when Integer then note
    when Float then freq_to_midi(note)
    else raise ArgumentError, "Can't convert #{note.class} to MIDI"
    end
  end

  def self.midi_to_freq(midi, a4 = 440.0)
    a4 * (2.0 ** ((midi - 69) / 12.0))
  end

  def self.freq_to_midi(freq, a4 = 440.0)
    (69 + 12 * Math.log2(freq / a4)).round
  end
end
