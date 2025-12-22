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

  SCALES = {
    major:            [0, 2, 4, 5, 7, 9, 11],
    minor:            [0, 2, 3, 5, 7, 8, 10],
    harmonic_minor:   [0, 2, 3, 5, 7, 8, 11],
    melodic_minor:    [0, 2, 3, 5, 7, 9, 11],
    dorian:           [0, 2, 3, 5, 7, 9, 10],
    phrygian:         [0, 1, 3, 5, 7, 8, 10],
    lydian:           [0, 2, 4, 6, 7, 9, 11],
    mixolydian:       [0, 2, 4, 5, 7, 9, 10],
    locrian:          [0, 1, 3, 5, 6, 8, 10],
    pentatonic:       [0, 2, 4, 7, 9],
    minor_pentatonic: [0, 3, 5, 7, 10],
    blues:            [0, 3, 5, 6, 7, 10],
    chromatic:        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    whole_tone:       [0, 2, 4, 6, 8, 10],
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

  # Primary logic for MIDI -> Frequency conversion
  def midi_to_freq(midi)
    A4_FREQ * (2.0 ** ((midi - A4_MIDI) / 12.0))
  end

  def freq(sym)
    midi_to_freq(midi(sym))
  end

  def midi_to_sym(m)
    "#{NOTE_NAMES[m % 12]}#{(m / 12) - 1}".to_sym
  end

  def chord(sym, type)
    m = midi(sym)
    CHORDS[type].map { |i| midi_to_sym(m + i) }
  end

  def scale(sym, type, octaves: 1)
    m = midi(sym)
    intervals = SCALES[type] or raise ArgumentError, "Unknown scale: #{type}"
    notes = []
    octaves.times do |oct|
      intervals.each { |i| notes << midi_to_sym(m + i + (oct * 12)) }
    end
    notes << midi_to_sym(m + (octaves * 12))  # include top note
    notes
  end

  def transpose(sym, semitones)
    midi_to_sym(midi(sym) + semitones)
  end
end
