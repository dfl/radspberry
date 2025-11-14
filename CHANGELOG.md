# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.2.0] - 2025-11-14

### Added
- Function composition API with `>>` operator for chaining generators and processors
- Parallel composition with `+` operator for mixing signal sources
- `crossfade(other, fade)` method for crossfading between generators
- Direct composition to Speaker: `generator >> processor >> Speaker`
- Comprehensive composition tests in test suite
- `COMPOSITION.md` documentation explaining function composition patterns
- `example_composition.rb` demonstrating new composition API

### Changed
- Replaced RAFL_wav with wavefile gem for WAV file generation
- Refactored `ProcessorChain` and `GeneratorChain` to use `reduce` instead of `inject`
- Simplified chain composition logic for better functional programming patterns
- Updated `to_wav` method to use WaveFile::Format, WaveFile::Buffer, and WaveFile::Writer

### Fixed
- Fixed `RpmNoise` missing `include DSP::Math` (caused NoMethodError for `sin`)
- Fixed Speaker frameSize parameter handling (nil was breaking PortAudio initialization)
- Fixed `Math.sqrt` namespace issues in `Mixer` and `GainMixer` (now uses `::Math.sqrt`)
- Fixed normalization bug in `to_wav` (changed `-data.max` to `-data.min`)

## [0.1.2] - 2014-03-16

### Changed
- Decoupled SuperSaw `mix` parameter from `spread` parameter
- Fixed SuperSaw `calc_side` polynomial calculation

### Added
- Zero-delay filters (ZDLP, ZDHP)
- Additional filter cleanup and improvements

## [0.1.2] - 2012-05-17

### Changed
- Cleaned up vector behavior for `Generator#ticks`
- Added `ArrayExtensions#to_v` for cleaner vector conversion

## [0.1.1] - 2012-05-16

### Added
- Speaker enhancements
- `param_accessor` macro for parameter management
- First release of working gem

### Changed
- Updated example to use `include DSP` namespace
- Fixed RpmSaw oscillator
- Improved Speaker implementation

## [0.1.0] - 2012-05-07

### Added
- Initial release
- Basic DSP framework with generators and processors
- Phasor, Tri, Pulse, RpmSaw, RpmSquare, RpmNoise oscillators
- SuperSaw oscillator based on Adam Szabo's thesis
- Biquad filters (ButterHP, ButterLP)
- Zero-delay filters (ZDLP, ZDHP, OnePoleZD)
- State Variable Filters (SVF, BellSVF)
- ProcessorChain and GeneratorChain for signal routing
- Mixer and XFader for combining signals
- Speaker module with PortAudio integration
- MIDI support
- Inspired by ffi-portaudio

[Unreleased]: https://github.com/yourusername/radspberry/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/yourusername/radspberry/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/yourusername/radspberry/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/yourusername/radspberry/releases/tag/v0.1.0
