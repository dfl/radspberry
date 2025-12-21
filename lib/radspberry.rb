class Radspberry
  VERSION = '0.2.0'
end

require 'matrix'

# require 'active_support'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/array/grouping'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/hash/reverse_merge'

require 'portmidi'
require 'wavefile'

require_relative './radspberry/ruby_extensions'
require_relative './radspberry/midi'
require_relative './radspberry/dsp/math'
require_relative './radspberry/dsp/base'
require_relative './radspberry/dsp/speaker'
require_relative './radspberry/dsp/native_speaker'
require_relative './radspberry/dsp/oscillator'
require_relative './radspberry/dsp/filter'
require_relative './radspberry/dsp/super_saw'
require_relative './radspberry/dsp/envelope'
