# Function Composition API

This library now supports Ruby's function composition operators (`>>`, `+`, and `crossfade`) for building DSP signal chains.

## Overview

Inspired by [Thoughtbot's article on Proc composition](https://thoughtbot.com/blog/proc-composition-in-ruby), Radspberry now allows you to compose DSP components using intuitive operators that reflect signal flow.

## Composition Operators

### `>>` - Serial Signal Flow (Left to Right)

Chain generators and processors in the order signals flow:

```ruby
# Traditional way
chain = GeneratorChain.new([Phasor.new(440), Hpf.new(100), ZDLP.new])

# Composition way
chain = Phasor.new(440) >> Hpf.new(100) >> ZDLP.new
```

The `>>` operator creates:
- `GeneratorChain` when composing Generator >> Processor
- `ProcessorChain` when composing Processor >> Processor

### `+` - Parallel Mixing

Mix multiple signal sources in parallel:

```ruby
# Traditional way
mixed = Mixer.new([Phasor.new(220), Phasor.new(440)])

# Composition way
mixed = Phasor.new(220) + Phasor.new(440)

# Mix multiple sources
mix = Phasor.new(220) + SuperSaw.new(110) + RpmNoise.new
```

### `crossfade(other, fade)` - Crossfading

Crossfade between two signal sources:

```ruby
# Traditional way
fader = XFader.new(source_a, source_b, 0.5)
# or
fader = XFader[source_a, source_b]

# Composition way
fader = source_a.crossfade(source_b, 0.5)
```

## Composing to Speaker

You can pipe signals directly to the Speaker using `>>`:

```ruby
# Traditional way
Speaker[Phasor.new(440)]

# Composition way
Phasor.new(440) >> Speaker

# With processing
Phasor.new(440) >> Hpf.new(100) >> Speaker

# Complex chains
(Phasor.new(220) + SuperSaw.new(110)) >> Hpf.new(80) >> ZDLP.new >> Speaker
```

## Real-Time Parameter Control

All composed chains maintain **mutable state**, allowing real-time parameter tweaking:

```ruby
# Build a chain
osc = Phasor.new(440)
chain = osc >> Hpf.new(100) >> Speaker

# Modify parameters in real-time
osc.freq = 880  # Still works!

# Access chain components
saw = SuperSaw.new(110)
fader = saw.crossfade(RpmNoise.new, 0.0)
Speaker[fader]

saw.spread = 0.9    # Modify the saw
fader.fade = 0.5    # Adjust crossfade
```

## Complex Examples

### Multi-Stage Processing

```ruby
signal = SuperSaw.new(55) >>
         Hpf.new(40, 0.7) >>
         ZDLP.new >>
         Spicer.new >>
         Speaker
```

### Parallel Processing & Mixing

```ruby
bass = SuperSaw.new(55) >> Hpf.new(40)
lead = Phasor.new(440) >> Hpf.new(100)
pad  = RpmNoise.new >> ZDLP.new

mix = bass + lead + pad >> Speaker
```

### Nested Composition

```ruby
# Mix two processed signals, then crossfade with a third
path_a = (Phasor.new(220) + Phasor.new(440)) >> Hpf.new(100)
path_b = RpmNoise.new >> ZDLP.new

result = path_a.crossfade(path_b, 0.3) >> Speaker
```

### Reusable Processing Chains

```ruby
# Define reusable effect chains as methods
def bass_processing
  Hpf.new(40, 0.7) >> ZDLP.new
end

def lead_processing
  Hpf.new(100) >> BellSVF.new
end

# Apply to different sources
bass = SuperSaw.new(55) >> bass_processing >> Speaker
sleep 3

lead = Phasor.new(440) >> lead_processing >> Speaker
```

## Benefits

1. **Visual Signal Flow**: Chains read left-to-right like signal path diagrams
2. **Less Nesting**: Eliminate deeply nested constructor calls
3. **Composable**: Build complex signals from simple building blocks
4. **Mutable**: Still allows real-time parameter tweaking
5. **Backward Compatible**: Original API (`GeneratorChain.new()`, `Mixer[]`, etc.) still works

## Implementation Details

### Under the Hood

The composition operators create the same objects as the traditional API:

```ruby
# These are equivalent:
Phasor.new >> Hpf.new
GeneratorChain.new([Phasor.new, Hpf.new])

# These are equivalent:
Phasor.new + RpmNoise.new
Mixer.new([Phasor.new, RpmNoise.new])

# These are equivalent:
a.crossfade(b, 0.5)
XFader.new(a, b, 0.5)
```

### Chain Optimization

Chains now use `reduce` for cleaner functional composition:

```ruby
# ProcessorChain implementation
def tick(input)
  @gain * @chain.reduce(input) { |signal, processor| processor.tick(signal) }
end
```

## Migration Guide

Your existing code works unchanged! The composition API is additive:

```ruby
# Old code still works
Speaker[Phasor.new]
chain = GeneratorChain.new([osc, filter])
mix = Mixer[osc1, osc2]
fade = XFader[a, b]

# New alternatives available
Phasor.new >> Speaker
chain = osc >> filter
mix = osc1 + osc2
fade = a.crossfade(b)
```

Choose whichever style you prefer, or mix both!

## See Also

- `example_composition.rb` - Working examples of composition API
- `example.rb` - Original API examples (still works)
- [Thoughtbot: Proc Composition in Ruby](https://thoughtbot.com/blog/proc-composition-in-ruby)
