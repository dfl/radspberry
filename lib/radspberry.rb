class Radspberry
  VERSION = '0.3.0'
end

require 'matrix'

require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/array/grouping'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/hash/reverse_merge'

require 'portmidi'
require 'wavefile'

require_relative './radspberry/ruby_extensions'
require_relative './radspberry/midi'

# Core DSP
require_relative './radspberry/dsp/math'
require_relative './radspberry/dsp/base'
require_relative './radspberry/dsp/speaker'

# Initialize sample rate from audio device before creating DSP objects
DSP.init_sample_rate_from_device!

require_relative './radspberry/dsp/native_speaker'

# Oscillators
require_relative './radspberry/dsp/oscillator'
require_relative './radspberry/dsp/super_saw'
require_relative './radspberry/dsp/dual_rpm_oscillator'
require_relative './radspberry/dsp/naive_rpm_sync'

# Modulation (must come before filters so they get the mixin)
require_relative './radspberry/dsp/modulation'

# Utilities
require_relative './radspberry/dsp/curvable'
require_relative './radspberry/dsp/oversampling'
require_relative './radspberry/dsp/fft'
require_relative './radspberry/dsp/note'
require_relative './radspberry/dsp/clock'
require_relative './radspberry/dsp/refinements'

# Filters
require_relative './radspberry/dsp/filter/dc_blocker'
require_relative './radspberry/dsp/filter/one_pole'
require_relative './radspberry/dsp/filter/biquad'
require_relative './radspberry/dsp/filter/butterworth'
require_relative './radspberry/dsp/filter/svf'
require_relative './radspberry/dsp/filter/param_smoother'

# Envelopes
require_relative './radspberry/dsp/envelope/analog'
require_relative './radspberry/dsp/envelope/fiber'
require_relative './radspberry/dsp/envelope/amp'
require_relative './radspberry/dsp/envelope/presets'
require_relative './radspberry/dsp/sequencer/step'
require_relative './radspberry/dsp/sequencer/arpeggiator'

# Voices
require_relative './radspberry/dsp/voice/voice'
require_relative './radspberry/dsp/voice/sequenced'