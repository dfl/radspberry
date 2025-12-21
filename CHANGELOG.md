# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2025-12-21

### Added
- `NativeSpeaker` with C extension for glitch-free audio via lock-free ring buffer
- `AudioRateSVF` TPT/Cytomic-style state variable filter with audio-rate modulation support
- 4x oversampling support with 12th-order elliptic anti-aliasing filter
- `DSP.oversample` and `DSP.oversampled` block syntax for oversampling chains
- ADSR envelopes, sequencer, and arpeggiator modules
- Refinements module (`DSP::Refinements`) for scoped DSP extensions
- Click-free audio stop with fade-out and DC blocking
- Auto-detection of audio device sample rate

### Fixed
- SuperSaw DC offset by centering phasors
- Oscillator clipping issues
- Envelopes thread-safety
- Sequencers thread-safety
- Oversampling to use quarter-band filter correctly for 4x only

### Changed
- Improved Speaker reliability with auto-detected sample rates

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
- `RpmNoise` missing `include DSP::Math` (caused NoMethodError for `sin`)
- Speaker frameSize parameter handling (nil was breaking PortAudio initialization)
- `Math.sqrt` namespace issues in `Mixer` and `GainMixer` (now uses `::Math.sqrt`)
- Normalization bug in `to_wav` (changed `-data.max` to `-data.min`)

## [0.1.2] - 2014-03-16

### Added
- Zero-delay filters (ZDLP, ZDHP)

### Changed
- Decoupled SuperSaw `mix` parameter from `spread` parameter
- Fixed SuperSaw `calc_side` polynomial calculation

## [0.1.1] - 2012-05-16

### Added
- Speaker enhancements
- `param_accessor` macro for parameter management

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

[Unreleased]: https://github.com/dfl/radspberry/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/dfl/radspberry/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/dfl/radspberry/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/dfl/radspberry/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/dfl/radspberry/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/dfl/radspberry/releases/tag/v0.1.0
