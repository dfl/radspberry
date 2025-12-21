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