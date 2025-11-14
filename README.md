# radspberry

[![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)](https://github.com/dfl/radspberry)

A real-time audio DSP library for Ruby based on ffi-portaudio, designed to create synthesizers,
apply filters, and generate audio in real-time with a simple, expressive API.

## Features

* Real-time output with ffi-portaudio (though timing is a bit unstable)
* Output to speaker or wave file
* Basic oscillator and filter classes
* MIDI has not been implemented yet (portmidi)

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


# Demonstrate that timing is unstable! 😬
20.times { Speaker.toggle; sleep 0.1 }
```

See `/examples` for more.

## Requirements

* Depends on ffi-portaudio (which depends on portaudio libs)

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

# Run an example
bundle exec rake examples/example_composition.rb
```