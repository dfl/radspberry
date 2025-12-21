# Sequenced and arpeggiated synth voices

module DSP
  class SequencedSynth < Generator
    attr_reader :voice, :sequencer

    def initialize(voice: nil, sequencer: nil)
      @voice = voice || Voice.new
      @sequencer = sequencer || StepSequencer.new
      @last_gate = 0.0
    end

    def tick
      gate = @sequencer.tick

      if gate > 0.5 && @last_gate <= 0.5
        @voice.note_on(@sequencer.current_note)
      elsif gate <= 0.5 && @last_gate > 0.5
        @voice.note_off
      end
      @last_gate = gate

      @voice.tick
    end

    def ticks(samples)
      samples.times.map { tick }.to_v
    end

    def pattern=(p)
      @sequencer.pattern = p
    end

    def step_duration=(d)
      @sequencer.step_duration = d
    end
  end


  class ArpSynth < Generator
    attr_reader :voice, :arpeggiator

    def initialize(voice: nil, notes: [60, 64, 67], step_duration: 0.125, mode: :up, octaves: 2)
      @voice = voice || Voice.new
      @arpeggiator = Arpeggiator.new(notes: notes, step_duration: step_duration,
                                      mode: mode, octaves: octaves)
      @last_gate = 0.0
    end

    def tick
      gate = @arpeggiator.tick

      if gate > 0.5 && @last_gate <= 0.5
        @voice.note_on(@arpeggiator.current_note)
      elsif gate <= 0.5 && @last_gate > 0.5
        @voice.note_off
      end
      @last_gate = gate

      @voice.tick
    end

    def ticks(samples)
      samples.times.map { tick }.to_v
    end

    def note_on(note)
      @arpeggiator.note_on(note)
    end

    def note_off(note)
      @arpeggiator.note_off(note)
    end

    def mode=(m)
      @arpeggiator.mode = m
      @arpeggiator.reset!
    end

    def step_duration=(d)
      @arpeggiator.step_duration = d
    end

    def octaves=(o)
      @arpeggiator.octaves = o
      @arpeggiator.reset!
    end
  end
end
