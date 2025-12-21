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
include DSP

# Play a note with Voice preset
voice = Voice.acid
Speaker.play(voice, volume: 0.4)
voice.play(:a2)
sleep 0.5
voice.stop
sleep 0.3
Speaker.stop
```

See `/examples` for more.

## Note Symbols

Use Ruby symbols for musical notes:

```ruby
:c4.freq           # => 261.63 Hz
:a4.midi           # => 69
:c4.major          # => [:c4, :e4, :g4]
:a3.minor7         # => [:a3, :c4, :e4, :g4]
:c4 + 7            # => :g4 (transpose up 7 semitones)

# Scales
:c3.scale(:major)              # => [:c3, :d3, :e3, :f3, :g3, :a3, :b3, :c4]
:c3.scale(:blues, octaves: 2)  # Two octaves of blues scale
:c3.scale(:dorian)             # Modal scales
```

Available scales: `major`, `minor`, `harmonic_minor`, `melodic_minor`, `dorian`, `phrygian`, `lydian`, `mixolydian`, `locrian`, `pentatonic`, `minor_pentatonic`, `blues`, `chromatic`, `whole_tone`.

## Voice Presets

Ready-to-use synthesizer voices:

```ruby
# Presets - optionally pass a note to start immediately
v = Voice.acid(:a2)    # TB-303 style acid bass
v = Voice.pad(:c3)     # Lush pad with slow attack
v = Voice.pluck(:e4)   # Plucky percussive sound
v = Voice.lead(:g4)    # Monophonic lead

# Control voices
v.play(:c4)            # Trigger note
v.stop                 # Release note

# Parameter aliases for clean API
v.cutoff = 2000        # Filter base frequency
v.resonance = 0.8      # Filter resonance (alias: v.res)
v.attack = 0.01        # Amp envelope attack
v.decay = 0.2          # Amp envelope decay
v.sustain = 0.6        # Amp envelope sustain level
v.release = 0.3        # Amp envelope release

# Bulk parameter update
v.set(cutoff: 1500, resonance: 0.5, attack: 0.05)
```

## Envelope Presets

```ruby
Env.perc                    # Quick percussive hit
Env.pluck                   # Plucked string decay
Env.pad                     # Slow pad envelope
Env.adsr(attack: 0.1, decay: 0.2, sustain: 0.6, release: 0.4)
Env.ad(attack: 0.01, decay: 0.5)
```

## Timing Extensions

```ruby
Clock.bpm = 140

sleep 1.beat      # Sleep for one beat (0.429s at 140 BPM)
sleep 0.5.beats   # Half beat
sleep 1.bar       # One bar (4 beats)
sleep 2.bars      # Two bars
```

## Modulation DSL

Declaratively modulate any parameter with an LFO or other source:

```ruby
filter = ButterLP.new(1000)
lfo = Phasor.new(5)  # 5Hz LFO

# Range-based modulation
filter = filter.modulate(:freq, lfo, range: 200..4000)

# Block-based (custom curve)
filter = filter.modulate(:q, lfo) { |v| 0.5 + v * 10 }

# Chain multiple modulations
filter = ButterLP.new(1000)
           .modulate(:freq, lfo1, range: 200..4000)
           .modulate(:q, lfo2, range: 0.5..10)

# Tick as normal - modulation happens automatically
output = filter.tick(input)
```

## Speaker API

```ruby
# Play any generator
Speaker.play(voice, volume: 0.4)

# Stop playback
Speaker.stop

# Check status
Speaker.playing?   # => true/false
```

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
