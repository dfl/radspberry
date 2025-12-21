# radspberry

[![Version](https://img.shields.io/badge/version-0.3.0-blue.svg)](https://github.com/dfl/radspberry/releases)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%202.7-red.svg)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.txt)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()

A real-time audio DSP library for Ruby based on ffi-portaudio, designed to create synthesizers, apply filters, and generate audio in real-time with a simple, expressive API.

## Features

- Real-time output with ffi-portaudio
- Native C extension for glitch-free audio
- Output to speaker or wave file
- Basic oscillator and filter classes
- MIDI input via portmidi
- Refinements for scoped DSP extensions
- 4x oversampling with anti-aliasing
- Audio-rate filter modulation

## Quick Start

```ruby
require 'radspberry'

# Start a simple oscillator
Speaker[ Phasor.new * 0.5 ]

# Change the frequency dynamically
2.times do
  Speaker.synth.freq /= 2
  sleep 1
end
Speaker.mute
```

See `/examples` for more.

## Installation

```bash
# Install portaudio
brew install portaudio  # macOS
# apt install portaudio19-dev  # Linux

# Clone the repository
git clone git@github.com:dfl/radspberry.git
cd radspberry

# Install dependencies
bundle install

# Build native extension (optional, for NativeSpeaker)
cd ext/radspberry_audio && ruby extconf.rb && make
mkdir -p ../../lib/radspberry_audio
cp radspberry_audio.bundle ../../lib/radspberry_audio/

# Run a demo
ruby examples/buffered_demo.rb
```

## Audio Stability & the GVL

The default `Speaker` uses ffi-portaudio's callback mode, where PortAudio's native audio thread calls into Ruby. This requires acquiring Ruby's Global VM Lock (GVL), which means heavy Ruby work (computation, GC) can cause audio glitches.

### NativeSpeaker (Glitch-Free Audio)

For stable audio during heavy Ruby work, use `NativeSpeaker` which uses a C extension:

```ruby
NativeSpeaker.new(SuperSaw.new(110), volume: 0.3)

# Audio stays smooth even during heavy computation
10.times { heavy_computation }

NativeSpeaker.stop
```

The C callback reads from a lock-free ring buffer without touching Ruby or the GVL. A Ruby producer thread fills the buffer in the background.

**Build the extension:**
```bash
cd ext/radspberry_audio
ruby extconf.rb
make
cp radspberry_audio.bundle ../../lib/radspberry_audio/
```

## Audio-Rate SVF Filter

The `AudioRateSVF` is a TPT/Cytomic-style state variable filter optimized for audio-rate modulation:

```ruby
# Create filter with saturation
svf = AudioRateSVF.new(freq: 1000, q: 4.0, kind: :low, drive: 12.0)

# Audio-rate frequency modulation (efficient - uses fast tan approximation)
lfo = Phasor.new(5)  # 5Hz LFO
noise = Noise.new

loop do
  mod_freq = 500 + lfo.tick * 2000  # Modulate 500-2500Hz
  output = svf.tick_with_mod(noise.tick, mod_freq)
end

# Filter modes: :low, :band, :high, :notch
# 4-pole mode (24dB/oct):
svf.four_pole = true
```

## 4x Oversampling

Oversampling reduces aliasing from nonlinear processing (saturation, distortion). Uses a 12th-order elliptic anti-aliasing filter.

### Wrap a single processor

```ruby
svf = AudioRateSVF.new(freq: 2000, drive: 18.0)
oversampled = DSP.oversample(svf)
chain = noise >> oversampled
```

### Run entire chain at 4x (recommended)

```ruby
chain = DSP.oversampled do
  osc = Phasor.new(440)
  filter = AudioRateSVF.new(freq: 2000, drive: 12.0)
  osc >> filter
end

# Everything inside runs at 176.4kHz, decimated to 44.1kHz at output
chain.to_wav(2, filename: "smooth_saturation.wav")
```

The chain approach is cleaner because all components use the correct sample rate automatically, and there's only one decimation point at output.

## Refinements (Scoped Extensions)

By default, radspberry adds helper methods globally to `Array`, `Vector`, and `Module`. If you prefer explicit, lexically-scoped extensions, use refinements instead:

```ruby
require 'radspberry'
using DSP::Refinements

# These methods only work in this file:
[1, 2, 3].to_v                    # => Vector[1, 2, 3]
Vector.zeros(4)                   # => Vector[0.0, 0.0, 0.0, 0.0]
[osc1, osc2].tick_sum             # Sum tick values from array of oscillators
```

Refinements are activated with `using` and are scoped to the current file—they won't leak into other parts of your codebase.

## Requirements

- Ruby >= 2.7
- portaudio library
- ffi-portaudio gem

## Documentation

- [CHANGELOG](CHANGELOG.md) - Version history and release notes
- [COMPOSITION](COMPOSITION.md) - Function composition patterns

## Future Ideas

Some directions worth exploring:

### Applicative-style modulation

Instead of manually updating parameters in a loop, declare modulation relationships:

```ruby
lfo = LFO.new(0.5)
filter = ButterLP.new(1000)

# Declarative: LFO modulates filter frequency between 200-2000 Hz
lfo.modulate(filter, :freq, range: 200..2000)

# Or with a custom curve
lfo.modulate(filter, :freq) { |lfo_val| 200 * (2 ** (lfo_val * 3)) }
```

### Fibers for envelopes/sequencers

Use Ruby's lightweight coroutines for stateful, event-driven generators:

```ruby
env = Fiber.new do
  100.times { |i| Fiber.yield(i / 100.0) }  # attack
  loop { Fiber.yield(1.0) }                  # sustain until released
end
```

### Signal graphs as data

Treat chains as inspectable/optimizable structures before execution:

```ruby
graph = osc >> gain(0.5) >> gain(0.8) >> filter
graph.optimize!  # => osc >> gain(0.4) >> filter
graph.compile!   # => generate specialized native code
```

### Parallel offline rendering with Ractors

For bounce-to-disk, split work across cores:

```ruby
samples = synth.parallel_render(seconds: 60, cores: 8)
```

## License

[MIT](LICENSE.txt) - Copyright (c) 2012-2025 David Lowenfels
