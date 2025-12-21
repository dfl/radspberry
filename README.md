# radspberry

[![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)](https://github.com/dfl/radspberry)

A real-time audio DSP library for Ruby based on ffi-portaudio, designed to create synthesizers,
apply filters, and generate audio in real-time with a simple, expressive API.

## Features

* Real-time output with ffi-portaudio
* Native C extension for glitch-free audio (see below)
* Output to speaker or wave file
* Basic oscillator and filter classes
* MIDI input via portmidi

## Example Usage

### Basic Oscillator

```ruby
# Start a simple phasor oscillator (scaled to save your eardrums!)
Speaker[ Phasor.new * 0.5 ]

# Change the frequency dynamically
2.times do
  Speaker.synth.freq /= 2
  sleep 1
end
Speaker.mute
```

See `/examples` for more.

## Audio Stability & the GVL

The default `Speaker` uses ffi-portaudio's callback mode, where PortAudio's native audio
thread calls into Ruby. This requires acquiring Ruby's Global VM Lock (GVL), which means
heavy Ruby work (computation, GC) can cause audio glitches.

### NativeSpeaker (Glitch-Free Audio)

For stable audio during heavy Ruby work, use `NativeSpeaker` which uses a C extension:

```ruby
# Instead of Speaker, use NativeSpeaker
NativeSpeaker.new(SuperSaw.new(110), volume: 0.3)

# Audio stays smooth even during heavy computation
10.times { heavy_computation }

NativeSpeaker.stop
```

The C callback reads from a lock-free ring buffer without touching Ruby or the GVL.
A Ruby producer thread fills the buffer in the background.

**Build the extension:**
```bash
cd ext/radspberry_audio
ruby extconf.rb
make
cp radspberry_audio.bundle ../../lib/radspberry_audio/
```

## Requirements

* portaudio library
* ffi-portaudio gem

## Installation

```bash
# Install portaudio
brew install portaudio

# Install ffi-portaudio gem
gem install ffi-portaudio

# Clone the repository
git clone git@github.com:dfl/radspberry.git
cd radspberry

# Install dependencies
bundle install

# Build native extension (optional, for NativeSpeaker)
cd ext/radspberry_audio && ruby extconf.rb && make
mkdir -p ../../lib/radspberry_audio
cp radspberry_audio.bundle ../../lib/radspberry_audio/

# Run the demo
ruby examples/buffered_demo.rb
```

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