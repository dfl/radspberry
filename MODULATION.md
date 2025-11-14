# Modulation & Automation

Radspberry now includes a comprehensive modulation and automation system for creating dynamic, expressive synthesizer patches.

## Features

### 1. Keyframe Automation

Schedule parameter changes over time with multiple interpolation modes.

```ruby
# Create automation with linear interpolation
auto = DSP::Automation.new(mode: :linear)
auto.add_keyframe(0.0, 440)    # Start at 440 Hz
auto.add_keyframe(2.0, 880)    # Sweep to 880 Hz over 2 seconds
auto.add_keyframe(4.0, 440)    # Back to 440 Hz

# Apply to a parameter
osc.freq = auto.tick  # Call in your audio loop
```

**Interpolation Modes:**
- `:linear` - Straight line between keyframes
- `:exponential` - Natural curves (great for frequency sweeps)
- `:cubic` - Smooth S-curves through keyframes
- `:step` - Hold value until next keyframe (sequencer-style)

**Additional Options:**
```ruby
auto = DSP::Automation.new(mode: :linear, loop: true)  # Loop automation
auto.reset!   # Reset playback to beginning
auto.clear!   # Remove all keyframes
```

### 2. LFOs (Low-Frequency Oscillators)

Continuous, cyclic modulation for vibrato, tremolo, filter sweeps, and more.

```ruby
# Create a sine LFO
lfo = DSP::LFO.sine(rate: 2.0, depth: 100, offset: 440)

# Apply to filter frequency
filter.freq = lfo.tick
```

**Available Waveforms:**
- `LFO.sine()` - Smooth, natural modulation
- `LFO.triangle()` - Linear up/down ramps
- `LFO.saw()` - Sawtooth ramp
- `LFO.square()` - On/off switching

**Custom Waveforms:**
```ruby
# Use any Generator as an LFO source
custom_osc = DSP::SuperSaw.new(1.0)
lfo = DSP::LFO.new(waveform: custom_osc, depth: 50)
```

### 3. ModSource Operators

Transform and combine modulation sources with operators:

```ruby
lfo = DSP::LFO.sine(rate: 1.0, depth: 1.0, offset: 0.0)

# Scale modulation amount
wide_mod = lfo.scale(500)       # or: lfo * 500

# Add offset
shifted = lfo.add_offset(1000)  # or: lfo + 1000

# Invert modulation
inverted = lfo.invert           # or: -lfo

# Chain operators
complex_mod = lfo.scale(200).add_offset(440)
```

### 4. Modulation Matrix

Manage multiple modulation routings in one place:

```ruby
matrix = DSP::ModMatrix.new

# Create LFOs
freq_lfo = DSP::LFO.sine(rate: 0.5, depth: 10)
filter_lfo = DSP::LFO.triangle(rate: 2.0, depth: 500)

# Set base parameter values
osc.freq = 220
filter.freq = 1500

# Connect LFOs to parameters
matrix.connect(freq_lfo, osc, :freq, depth: 1.0)
matrix.connect(filter_lfo, filter, :freq, depth: 1.0)

# Update all modulations (call in your audio loop)
matrix.tick
```

**Matrix Operations:**
```ruby
matrix.disconnect(lfo, target, :param)        # Remove connection
matrix.clear!                                 # Remove all connections
matrix.update_base_value(target, :param, val) # Update base value
```

## Complete Example

```ruby
require_relative 'lib/radspberry'
include DSP

# Create synth
osc = RpmSaw.new(220)
filter = ButterLP.new(1000, q: 3.0)
synth = osc >> filter
Speaker[synth]

# Setup modulation matrix
matrix = ModMatrix.new

# Slow filter sweep (automation)
filter_auto = Automation.new(mode: :exponential, loop: true)
filter_auto.add_keyframe(0.0, 500)
filter_auto.add_keyframe(2.0, 3000)
filter_auto.add_keyframe(4.0, 500)

# Fast vibrato (LFO)
vibrato = LFO.sine(rate: 5.0, depth: 5, offset: 0)

# Apply in audio loop
loop do
  # Get automated base frequency
  base_freq = filter_auto.tick

  # Apply automation + LFO
  filter.freq = base_freq + vibrato.tick

  sleep 0.01  # ~100 Hz update rate
end
```

## Tips & Best Practices

1. **Update Rate**: Call `tick` in your control loop (10-100 Hz is usually sufficient for smooth modulation)

2. **Exponential Mode for Frequency**: Use exponential interpolation for frequency-based parameters (sounds more natural)

3. **Combine Techniques**: Layer automation (slow changes) with LFOs (fast movement) for expressive results

4. **ModMatrix for Complex Patches**: Use the modulation matrix when you have multiple modulation sources to keep code organized

5. **Sample & Hold**: Use the existing `SampleHold` generator with the LFO system for random modulation:
   ```ruby
   random_lfo = SampleHold.new(3.0)  # Random values at 3 Hz
   scaled = random_lfo.scale(1000).add_offset(500)
   ```

## See Also

- `examples/example_automation.rb` - Automation examples with all interpolation modes
- `examples/example_modulation.rb` - LFO and modulation matrix examples
- `test/test_modulation.rb` - Comprehensive test suite

## Architecture

- **ModSource** - Base class for all modulation sources
- **Automation** - Time-based keyframe interpolation
- **LFO** - Cyclic waveform modulation
- **ModMatrix** - Centralized modulation routing
- **ScaledModSource** / **OffsetModSource** - Modulation transformations
