# radspberry

[![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)](https://github.com/dfl/radspberry)

A real-time audio DSP library for Ruby based on ffi-portaudio

* https://github.com/dfl/radspberry

## Description

A real-time audio DSP library for Ruby based on ffi-portaudio. Create synthesizers, apply filters, and generate audio in real-time with a simple, expressive API.

## Features

* Real-time output with ffi-portaudio
* Output to speaker and wave files
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

## License

(The MIT License)

Copyright (c) 2012 David Lowenfels

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
