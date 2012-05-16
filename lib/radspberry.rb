class Radspberry
  VERSION = '0.1.1'
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
require 'radspberry/dsp/math'
require 'radspberry/dsp/base'
require 'radspberry/dsp/speaker'
require 'radspberry/dsp/oscillator'
require 'radspberry/dsp/filter'
require 'radspberry/dsp/super_saw'
