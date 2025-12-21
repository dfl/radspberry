# Envelopes and sequencers
#
# Two styles:
# - AnalogEnvelope: RC-style exponential curves (Pirkle/EarLevel method)
# - Fiber-based: natural state-machine semantics for sequencers
#
# The analog approach uses coefficient = exp(-log((1+TCO)/TCO) / rate)
# where TCO (target ratio) controls curve shape.

module DSP

  # Simple DC blocking filter (first-order high-pass at ~10Hz)
  # y[n] = x[n] - x[n-1] + R * y[n-1]
  class DCBlocker < Processor
    def initialize(r: 0.995)
      @r = r
      @x_prev = 0.0
      @y_prev = 0.0
    end

    def tick(input)
      output = input - @x_prev + @r * @y_prev
      @x_prev = input
      @y_prev = output
      output
    end

    def clear!
      @x_prev = 0.0
      @y_prev = 0.0
    end
  end

  # Convenience constructors for common envelope shapes
  module Env
    extend self

    # Quick percussive hit
    def perc(attack: 0.005, decay: 0.2)
      AnalogADEnvelope.new(attack: attack, decay: decay)
    end

    # Very short pluck
    def pluck(attack: 0.001, decay: 0.1)
      AnalogADEnvelope.new(attack: attack, decay: decay)
    end

    # Slow pad envelope
    def pad(attack: 0.5, decay: 0.3, sustain: 0.7, release: 0.8)
      AnalogEnvelope.new(attack: attack, decay: decay, sustain: sustain, release: release)
    end

    # Classic ADSR with sensible defaults
    def adsr(attack: 0.01, decay: 0.1, sustain: 0.7, release: 0.3)
      AnalogEnvelope.new(attack: attack, decay: decay, sustain: sustain, release: release)
    end

    # Attack-decay only
    def ad(attack: 0.01, decay: 0.2)
      AnalogADEnvelope.new(attack: attack, decay: decay)
    end

    # Slow attack swell
    def swell(attack: 1.0, decay: 0.5, sustain: 0.8, release: 0.5)
      AnalogEnvelope.new(attack: attack, decay: decay, sustain: sustain, release: release)
    end

    # Gate-only (instant attack, instant release)
    def gate
      AnalogEnvelope.new(attack: 0.001, decay: 0.001, sustain: 1.0, release: 0.001)
    end
  end


  # Analog-style ADSR using exponential RC curves
  # Based on Will Pirkle / EarLevel Engineering method
  # Sounds more natural than linear envelopes
  class AnalogEnvelope < Generator
    IDLE = 0
    ATTACK = 1
    DECAY = 2
    SUSTAIN = 3
    RELEASE = 4

    attr_accessor :attack_time, :decay_time, :sustain_level, :release_time
    attr_reader :state, :output

    # Aliases for more natural API
    alias_method :attack,  :attack_time
    alias_method :attack=, :attack_time=
    alias_method :decay,   :decay_time
    alias_method :decay=,  :decay_time=
    alias_method :sustain, :sustain_level
    alias_method :sustain=,:sustain_level=
    alias_method :release, :release_time
    alias_method :release=,:release_time=

    # TCO = Target Coefficient Overshoot
    # Small values (0.0001) = more exponential
    # Large values (100) = more linear
    DEFAULT_TCO_ATTACK = 0.3      # Attack curves up
    DEFAULT_TCO_DECAY = 0.0001    # Decay/release curves down sharply

    def initialize(attack: 0.01, decay: 0.1, sustain: 0.7, release: 0.3,
                   tco_attack: DEFAULT_TCO_ATTACK, tco_decay: DEFAULT_TCO_DECAY)
      @attack_time = attack
      @decay_time = decay
      @sustain_level = sustain
      @release_time = release
      @tco_attack = tco_attack
      @tco_decay = tco_decay

      @state = IDLE
      @output = 0.0

      recalc_coefficients!
    end

    def gate_on!
      @state = ATTACK
      recalc_coefficients!
    end

    def gate_off!
      if @state != IDLE
        @state = RELEASE
        # release_base is already correctly calculated in recalc_coefficients!
        # It should be -@tco_decay * (1.0 - @release_coef) to decay toward 0
        # (targeting -TCO as overshoot below 0)
      end
    end

    def trigger!
      gate_on!
    end

    def tick
      case @state
      when IDLE
        @output = 0.0

      when ATTACK
        @output = @attack_base + @output * @attack_coef
        if @output >= 1.0
          @output = 1.0
          @state = DECAY
        end

      when DECAY
        @output = @decay_base + @output * @decay_coef
        if @output <= @sustain_level
          @output = @sustain_level
          @state = SUSTAIN
        end

      when SUSTAIN
        @output = @sustain_level

      when RELEASE
        @output = @release_base + @output * @release_coef
        if @output <= 0.0001
          @output = 0.0
          @state = IDLE
        end
      end

      @output
    end

    def ticks(samples)
      samples.times.map { tick }.to_v
    end

    def idle?
      @state == IDLE
    end

    def active?
      @state != IDLE
    end

    private

    def recalc_coefficients!
      # Attack coefficient and base
      attack_samples = [@attack_time * srate, 1].max
      @attack_coef = calc_coef(attack_samples, @tco_attack)
      @attack_base = (1.0 + @tco_attack) * (1.0 - @attack_coef)

      # Decay coefficient and base
      decay_samples = [@decay_time * srate, 1].max
      @decay_coef = calc_coef(decay_samples, @tco_decay)
      @decay_base = (@sustain_level - @tco_decay) * (1.0 - @decay_coef)

      # Release coefficient (base calculated when release starts)
      release_samples = [@release_time * srate, 1].max
      @release_coef = calc_coef(release_samples, @tco_decay)
      @release_base = -@tco_decay * (1.0 - @release_coef)
    end

    def calc_coef(rate, tco)
      ::Math.exp(-::Math.log((1.0 + tco) / tco) / rate)
    end
  end

  # Simpler AD version of analog envelope
  class AnalogADEnvelope < AnalogEnvelope
    def initialize(attack: 0.01, decay: 0.3, **opts)
      super(attack: attack, decay: decay, sustain: 0.0, release: 0.001, **opts)
    end

    def gate_on!
      @state = ATTACK
      recalc_coefficients!
    end

    # AD envelope goes straight to decay after attack, ignores gate_off
    def tick
      case @state
      when IDLE
        @output = 0.0

      when ATTACK
        @output = @attack_base + @output * @attack_coef
        if @output >= 1.0
          @output = 1.0
          @state = DECAY
        end

      when DECAY
        @output = @decay_base + @output * @decay_coef
        if @output <= 0.0001
          @output = 0.0
          @state = IDLE
        end
      end

      @output
    end
  end

  # Base class for Fiber-based generators
  class FiberGenerator < Generator
    def initialize
      @fiber = nil
      @current_value = 0.0
      reset!
    end

    def tick
      @current_value = @fiber.resume if @fiber&.alive?
      @current_value
    end

    def reset!
      @fiber = create_fiber
      @current_value = 0.0
    end

    def alive?
      @fiber&.alive?
    end

    protected

    def create_fiber
      raise "Subclass must implement create_fiber"
    end
  end

  # Attack-Decay envelope
  # Triggers on creation or reset!, runs once
  class ADEnvelope < FiberGenerator
    attr_accessor :attack, :decay, :curve

    def initialize(attack: 0.01, decay: 0.1, curve: :linear)
      @attack = attack
      @decay = decay
      @curve = curve
      super()
    end

    def trigger!
      reset!
    end

    protected

    def create_fiber
      Fiber.new do
        attack_samples = (@attack * srate).to_i
        decay_samples = (@decay * srate).to_i

        # Attack: 0 -> 1
        attack_samples.times do |i|
          Fiber.yield(apply_curve(i.to_f / attack_samples, :up))
        end

        # Decay: 1 -> 0
        decay_samples.times do |i|
          Fiber.yield(apply_curve(1.0 - i.to_f / decay_samples, :down))
        end

        # Done - output 0 forever
        loop { Fiber.yield(0.0) }
      end
    end

    private

    def apply_curve(value, direction)
      case @curve
      when :linear
        value
      when :exponential
        direction == :up ? value ** 2 : value ** 0.5
      when :logarithmic
        direction == :up ? value ** 0.5 : value ** 2
      else
        value
      end
    end
  end

  # Attack-Decay-Sustain-Release envelope
  # Stays at sustain until gate_off! is called
  class ADSREnvelope < FiberGenerator
    attr_accessor :attack, :decay, :sustain, :release, :curve

    def initialize(attack: 0.01, decay: 0.1, sustain: 0.7, release: 0.2, curve: :linear)
      @attack = attack
      @decay = decay
      @sustain = sustain
      @release = release
      @curve = curve
      @gate = false
      @release_from = 0.0
      super()
    end

    def gate_on!
      @gate = true
      reset!
    end

    def gate_off!
      @gate = false
      @release_from = @current_value
    end

    def trigger!
      gate_on!
    end

    protected

    def create_fiber
      Fiber.new do
        attack_samples = (@attack * srate).to_i
        decay_samples = (@decay * srate).to_i
        release_samples = (@release * srate).to_i

        # Attack: 0 -> 1
        attack_samples.times do |i|
          Fiber.yield(apply_curve(i.to_f / attack_samples, :up))
        end

        # Decay: 1 -> sustain
        decay_samples.times do |i|
          level = 1.0 - (1.0 - @sustain) * (i.to_f / decay_samples)
          Fiber.yield(level)
        end

        # Sustain: hold until gate off
        while @gate
          Fiber.yield(@sustain)
        end

        # Release: current level -> 0
        release_samples.times do |i|
          level = @release_from * (1.0 - i.to_f / release_samples)
          Fiber.yield(apply_curve(level, :down))
        end

        # Done
        loop { Fiber.yield(0.0) }
      end
    end

    private

    def apply_curve(value, direction)
      case @curve
      when :linear
        value
      when :exponential
        direction == :up ? value ** 2 : value ** 0.5
      when :logarithmic
        direction == :up ? value ** 0.5 : value ** 2
      else
        value
      end
    end
  end

  # Amplitude envelope - wraps a generator and applies envelope
  class AmpEnvelope < Generator
    attr_reader :envelope, :source

    def initialize(source, envelope)
      @source = source
      @envelope = envelope
    end

    def tick
      @source.tick * @envelope.tick
    end

    def ticks(samples)
      # Element-wise multiplication of source and envelope
      src = @source.ticks(samples).to_a
      env = @envelope.ticks(samples).to_a
      src.zip(env).map { |s, e| s * e }.to_v
    end

    def trigger!
      @envelope.trigger!
    end

    def gate_on!
      @envelope.gate_on! if @envelope.respond_to?(:gate_on!)
    end

    def gate_off!
      @envelope.gate_off! if @envelope.respond_to?(:gate_off!)
    end

    # Delegate to source
    def method_missing(method, *args, &block)
      if @source.respond_to?(method)
        @source.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @source.respond_to?(method, include_private) || super
    end
  end

  # Filter envelope - modulates a filter parameter
  class FilterEnvelope < Processor
    attr_reader :envelope, :filter
    attr_accessor :base_freq, :mod_range

    def initialize(filter, envelope, base_freq: 200, mod_range: 4000)
      @filter = filter
      @envelope = envelope
      @base_freq = base_freq
      @mod_range = mod_range
    end

    def tick(input)
      env_val = @envelope.tick
      @filter.freq = @base_freq + env_val * @mod_range
      @filter.tick(input)
    end

    def ticks(inputs)
      inputs.map { |s| tick(s) }
    end

    def trigger!
      @envelope.trigger!
    end

    def gate_on!
      @envelope.gate_on! if @envelope.respond_to?(:gate_on!)
    end

    def gate_off!
      @envelope.gate_off! if @envelope.respond_to?(:gate_off!)
    end
  end

  # Step sequencer - cycles through a pattern
  # Uses state machine instead of Fiber for thread-safety with PortAudio callbacks
  class StepSequencer < Generator
    attr_accessor :pattern, :step_duration, :looping

    def initialize(pattern: [60, 62, 64, 65], step_duration: 0.25, looping: true)
      @pattern = pattern
      @step_duration = step_duration
      @looping = looping
      reset!
    end

    def reset!
      @current_step = 0
      @current_note = @pattern.first
      @sample_in_step = 0
      @samples_per_step = (@step_duration * srate).to_i
      @gate_samples = (@samples_per_step * 0.8).to_i
      @done = false
    end

    def current_note
      @current_note
    end

    def current_freq
      midi_to_freq(@current_note)
    end

    def tick
      return 0.0 if @done

      # Determine gate state
      gate = @sample_in_step < @gate_samples ? 1.0 : 0.0

      # Advance sample counter
      @sample_in_step += 1

      # Move to next step if needed
      if @sample_in_step >= @samples_per_step
        @sample_in_step = 0
        @current_step += 1

        if @current_step >= @pattern.size
          if @looping
            @current_step = 0
          else
            @done = true
            return 0.0
          end
        end

        @current_note = @pattern[@current_step]
      end

      gate
    end

    private

    def midi_to_freq(note)
      440.0 * (2.0 ** ((note - 69) / 12.0))
    end
  end

  # Arpeggiator - cycles through held notes
  # Uses state machine instead of Fiber for thread-safety with PortAudio callbacks
  class Arpeggiator < Generator
    MODES = [:up, :down, :up_down, :random]

    attr_accessor :notes, :step_duration, :octaves, :mode

    def initialize(notes: [60, 64, 67], step_duration: 0.125, octaves: 1, mode: :up)
      @notes = notes.sort
      @step_duration = step_duration
      @octaves = octaves
      @mode = mode
      reset!
    end

    def reset!
      @arp_sequence = build_arp_sequence
      @current_index = 0
      @current_note = @arp_sequence.first || @notes.first
      @sample_in_step = 0
      @samples_per_step = (@step_duration * srate).to_i
      @gate_samples = (@samples_per_step * 0.8).to_i
    end

    def note_on(note)
      @notes << note unless @notes.include?(note)
      @notes.sort!
      reset!
    end

    def note_off(note)
      @notes.delete(note)
      reset! if @notes.any?
    end

    def current_note
      @current_note
    end

    def current_freq
      midi_to_freq(@current_note)
    end

    def tick
      return 0.0 if @notes.empty? || @arp_sequence.empty?

      # Determine gate state
      gate = @sample_in_step < @gate_samples ? 1.0 : 0.0

      # Advance sample counter
      @sample_in_step += 1

      # Move to next note if needed
      if @sample_in_step >= @samples_per_step
        @sample_in_step = 0
        @current_index += 1

        if @current_index >= @arp_sequence.size
          @current_index = 0
          # Rebuild sequence for random mode
          @arp_sequence = build_arp_sequence if @mode == :random
        end

        @current_note = @arp_sequence[@current_index]
      end

      gate
    end

    private

    def build_arp_sequence
      return [] if @notes.empty?

      # Expand across octaves
      expanded = []
      @octaves.times do |oct|
        @notes.each { |n| expanded << n + (oct * 12) }
      end

      case @mode
      when :up
        expanded
      when :down
        expanded.reverse
      when :up_down
        return expanded if expanded.size <= 2
        expanded + expanded.reverse[1..-2]
      when :random
        expanded.shuffle
      else
        expanded
      end
    end

    def midi_to_freq(note)
      440.0 * (2.0 ** ((note - 69) / 12.0))
    end
  end

  # Voice - combines oscillator + filter + amp envelope
  # A complete synth voice with analog-style envelopes
  class Voice < Generator
    attr_reader :osc, :filter, :amp_env, :filter_env
    attr_accessor :filter_base, :filter_mod

    # Accept osc/filter as class or instance
    def initialize(osc: SuperSaw, filter: ButterLP, amp_env: nil, filter_env: nil,
                   filter_base: 200, filter_mod: 4000, &block)
      @osc = osc.is_a?(Class) ? osc.new : osc
      @filter = filter.is_a?(Class) ? filter.new(1000) : filter
      @amp_env = amp_env || Env.adsr
      @filter_env = filter_env || Env.perc
      @filter_base = filter_base
      @filter_mod = filter_mod

      # Allow block-based configuration
      block.call(self) if block
    end

    # Presets
    def self.acid(note = nil)
      v = new(
        osc: RpmSaw,
        filter: ButterLP,
        amp_env: Env.adsr(attack: 0.005, decay: 0.1, sustain: 0.0, release: 0.05),
        filter_env: Env.perc(attack: 0.001, decay: 0.15),
        filter_base: 250,
        filter_mod: 3500
      )
      v.play(note) if note
      v
    end

    def self.pad(note = nil)
      v = new(
        osc: SuperSaw,
        filter: ButterLP,
        amp_env: Env.pad,
        filter_env: Env.ad(attack: 0.5, decay: 1.0),
        filter_base: 300,
        filter_mod: 2000
      )
      v.play(note) if note
      v
    end

    def self.pluck(note = nil)
      v = new(
        osc: RpmSquare,
        filter: ButterLP,
        amp_env: Env.adsr(attack: 0.002, decay: 0.15, sustain: 0.3, release: 0.1),
        filter_env: Env.pluck,
        filter_base: 400,
        filter_mod: 5000
      )
      v.play(note) if note
      v
    end

    def self.lead(note = nil)
      v = new(
        osc: RpmSaw,
        filter: ButterLP,
        amp_env: Env.adsr(attack: 0.01, decay: 0.2, sustain: 0.6, release: 0.2),
        filter_env: Env.ad(attack: 0.01, decay: 0.3),
        filter_base: 500,
        filter_mod: 3000
      )
      v.play(note) if note
      v
    end

    # Frequency: accepts Hz, MIDI, or note symbol
    def freq=(f)
      @freq = DSP.to_freq(f)
      @osc.freq = @freq if @osc.respond_to?(:freq=)
    end

    def freq
      @freq
    end

    # Aliases for less surprise
    def play(note)
      note_on(note)
    end

    def stop
      note_off
    end

    def note_on(note)
      self.freq = note
      @amp_env.gate_on!
      @filter_env.trigger!
    end

    def note_off
      @amp_env.gate_off!
    end

    # Direct envelope access with cleaner names
    def volume=(v)
      # Could add a gain stage, for now just document it's not supported
      raise NotImplementedError, "Use amp_env for volume shaping"
    end

    def cutoff
      @filter.freq
    end

    def cutoff=(f)
      @filter_base = DSP.to_freq(f)
    end

    def tick
      env_val = @filter_env.tick
      @filter.freq = @filter_base + env_val * @filter_mod

      sample = @osc.tick
      sample = @filter.tick(sample)
      sample * @amp_env.tick
    end

    def ticks(samples)
      samples.times.map { tick }.to_v
    end
  end

  # Sequenced synth - combines a voice with a sequencer
  class SequencedSynth < Generator
    attr_reader :voice, :sequencer

    def initialize(voice: nil, sequencer: nil)
      @voice = voice || Voice.new
      @sequencer = sequencer || StepSequencer.new
      @last_gate = 0.0
    end

    def tick
      gate = @sequencer.tick

      # Detect gate transitions
      if gate > 0.5 && @last_gate <= 0.5
        @voice.note_on(@sequencer.current_note)
      elsif gate <= 0.5 && @last_gate > 0.5
        @voice.note_off
      end
      @last_gate = gate

      @voice.tick
    end

    def ticks(samples)
      samples.times.map { tick }.to_v
    end

    # Delegate pattern changes to sequencer
    def pattern=(p)
      @sequencer.pattern = p
    end

    def step_duration=(d)
      @sequencer.step_duration = d
    end
  end

  # Arpeggiated synth
  class ArpSynth < Generator
    attr_reader :voice, :arpeggiator

    def initialize(voice: nil, notes: [60, 64, 67], step_duration: 0.125, mode: :up, octaves: 2)
      @voice = voice || Voice.new
      @arpeggiator = Arpeggiator.new(notes: notes, step_duration: step_duration,
                                      mode: mode, octaves: octaves)
      @last_gate = 0.0
    end

    def tick
      gate = @arpeggiator.tick

      if gate > 0.5 && @last_gate <= 0.5
        @voice.note_on(@arpeggiator.current_note)
      elsif gate <= 0.5 && @last_gate > 0.5
        @voice.note_off
      end
      @last_gate = gate

      @voice.tick
    end

    def ticks(samples)
      samples.times.map { tick }.to_v
    end

    def note_on(note)
      @arpeggiator.note_on(note)
    end

    def note_off(note)
      @arpeggiator.note_off(note)
    end

    def mode=(m)
      @arpeggiator.mode = m
      @arpeggiator.reset!
    end

    def step_duration=(d)
      @arpeggiator.step_duration = d
    end

    def octaves=(o)
      @arpeggiator.octaves = o
      @arpeggiator.reset!
    end
  end

end
