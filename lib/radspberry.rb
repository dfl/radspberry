class Radspberry
  VERSION = '0.1.0'
end

require 'matrix'

# require 'active_support'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/array/grouping'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/hash/reverse_merge'

require 'portmidi'
require 'radspberry/RAFL_wav'

require 'radspberry/ruby_extensions'
require 'radspberry/midi'
require 'radspberry/dsp_math'
require 'radspberry/dsp'
require 'radspberry/speaker'
require 'radspberry/oscillator'
require 'radspberry/filter'
require 'radspberry/super_saw'
