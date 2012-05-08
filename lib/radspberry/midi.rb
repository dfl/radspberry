# require 'portmidi'
require 'active_support/core_ext/object/try'

require 'midi-eye'

module MIDI
  extend self
  @@input = nil

  def input
    return @@input if @@input
    @@input = UniMIDI::Input.first.tap do
      sleep 1.5
    end
  end

  at_exit do
    if @@input
      puts "closing Midi"
      @@input.close
    end
  end     
  
  A = 432.0
  def note_to_freq( note, a = A ) # equal tempered
    a * 2.0**((note-69)/12.0)
  end

  KRYSTAL = [ 256.0, 272.0, 288.0, 305.0, 320.0, 1024.0/3, 360.0, 384.0, 405.0, 432.0, 455.1, 480.0 ]
  def krystal_freq( note )
    KRYSTAL[ note % 12 ] * 2.0**( note / 12 - 5 )
  end

  module Player
    require './speaker'

    extend self

    def [] gen      
      Speaker[ @gen = gen ].volume = 0
      @player = MIDIEye::Listener.new( MIDI.input )
      @player.listen_for(:class => [MIDIMessage::NoteOn, MIDIMessage::NoteOff]) do |event|
        p note = event[:message]
        case note
        when MIDIMessage::NoteOn
          Speaker.volume = note.velocity.to_i / 128.0
          @gen.freq = MIDI::krystal_freq( note.note )
        when MIDIMessage::NoteOff
          Speaker.volume = 0
        end
      end
      @player.run(:background => true)

      at_exit do
        @player.join
      end
    end

  end
  
end 

