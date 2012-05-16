require 'portmidi'

module MIDI
  extend self

  def devices
    Portmidi.input_devices
  end
  
  def select_device arg
    raise ArgumentError, "device doesn't exist\n  choose from: #{devices}" unless devices[arg]
    input.try(:close)
    @@input  = nil
    @@device = arg
  end

  def device
    @@device ||= 0
  end

  @@input = nil
  at_exit do
    if @@input
      puts "closing PortMidi device..."
      @@input.close
      puts "done!"
    end
  end
  
  def input
    @@input ||= devices && Portmidi::Input.new( device )
  end

  class Note < Struct.new( :note, :velocity, :channel, :delta ); end

  def process num=16
    return [] unless events = input.read(num)
    events.map do |event|
      midiData = event[:message]
      channel  = midiData[0] & 0x0f # is this correct??
      case status = midiData[0] & 0xf0 # ignore channel
      when 0x90, 0x80
        note     = midiData[1] & 0x7f # we only look at notes
        velocity = (status == 0x80) ? 0 : midiData[2] & 0x7f
        Note.new note, velocity, channel, event[:timestamp]
      when 0xb0
        :all_notes_off if [0x7e, 0x7b].include?( midiData[1] )
      end
    end
  end

  
  A = 432.0
  def note_to_freq( note, a = A ) # equal tempered
    a * 2.0**((note-69)/12.0)
  end

  def processVst(events)
    events.get_events().each do |event|
      next unless event.getType == VSTEvent::VST_EVENT_MIDI_TYPE
      midiData = event.getData
      channel  = midiData[0] & 0x0f # is this correct??

      case status = midiData[0] & 0xf0 # ignore channel
      when 0x90, 0x80
        note     = midiData[1] & 0x7f # we only look at notes
        velocity = (status == 0x80) ? 0 : midiData[2] & 0x7f
        yield :note_on, note, velocity, event.getDeltaFrames
      when 0xb0
        yield :all_notes_off if [0x7e, 0x7b].include?( midiData[1] )
      end
    end
  end

  KRYSTAL = [ 256.0, 272.0, 288.0, 305.0, 320.0, 1024.0/3, 360.0, 384.0, 405.0, 432.0, 455.1, 480.0 ]
  def krystal_freq( note )
    KRYSTAL[ note % 12 ] * 2.0**( note / 12 - 5 )
  end

  module Player
    extend self

    def [] gen      
      DSP::Speaker[ @gen = gen ].volume = 0
      loop do
        MIDI::process.each do |event|
          case event
          when Note
            p event
            DSP::Speaker.volume = event.velocity / 128.0
            @gen.freq = MIDI::krystal_freq( event.note )
          else :all_notes_off
            DSP::Speaker.volume = 0
          end
        end
      end
    end

  end
  
end 

