module DSP

  # Base class for modulation sources
  # Any class that implements tick() can be a modulation source
  class ModSource < Base
    def tick
      raise "not implemented!"
    end

    # Scale the modulation output
    def scale(amount)
      ScaledModSource.new(self, amount)
    end

    alias_method :*, :scale

    # Add offset to modulation output
    def add_offset(amount)
      OffsetModSource.new(self, amount)
    end

    alias_method :+, :add_offset

    # Invert the modulation
    def invert
      scale(-1.0)
    end

    alias_method :-@, :invert
  end

  # Wraps a ModSource with a scalar multiplier
  class ScaledModSource < ModSource
    def initialize(source, scale)
      @source = source
      @scale = scale
    end

    def tick
      @source.tick * @scale
    end
  end

  # Wraps a ModSource with an offset
  class OffsetModSource < ModSource
    def initialize(source, offset)
      @source = source
      @offset = offset
    end

    def tick
      @source.tick + @offset
    end
  end

  # Keyframe automation with multiple interpolation modes
  class Automation < ModSource
    attr_reader :keyframes, :mode
    attr_accessor :loop

    MODES = [:linear, :exponential, :cubic, :step]

    def initialize(mode: :linear, loop: false)
      raise ArgumentError, "Invalid mode: #{mode}. Use one of #{MODES}" unless MODES.include?(mode)
      @mode = mode
      @loop = loop
      @keyframes = []  # Array of [time, value] pairs
      @current_time = 0.0
      @last_value = 0.0
    end

    # Add a keyframe at a specific time (in seconds)
    def add_keyframe(time, value)
      @keyframes << [time, value]
      @keyframes.sort_by! { |kf| kf[0] }  # Keep sorted by time
      self
    end

    alias_method :at, :add_keyframe

    # Remove all keyframes
    def clear!
      @keyframes.clear
      @current_time = 0.0
      @last_value = 0.0
    end

    # Reset playback to beginning
    def reset!
      @current_time = 0.0
      @last_value = 0.0
    end

    # Get the current value at the current time
    def tick
      return 0.0 if @keyframes.empty?

      # Advance time by one sample
      @current_time += inv_srate

      # Handle looping
      if @loop && @keyframes.size > 0
        duration = @keyframes.last[0]
        @current_time = @current_time % duration if duration > 0
      end

      @last_value = value_at(@current_time)
    end

    # Get value at a specific time (without advancing)
    def value_at(time)
      return 0.0 if @keyframes.empty?
      return @keyframes.first[1] if @keyframes.size == 1

      # Check if time exactly matches a keyframe
      exact_match = @keyframes.find { |kf| (kf[0] - time).abs < 1e-9 }
      return exact_match[1] if exact_match

      # Find surrounding keyframes
      idx = @keyframes.index { |kf| kf[0] > time }

      # Before first keyframe
      return @keyframes.first[1] if idx == 0

      # After last keyframe
      if idx.nil?
        return @loop ? @keyframes.first[1] : @keyframes.last[1]
      end

      # Between two keyframes
      t1, v1 = @keyframes[idx - 1]
      t2, v2 = @keyframes[idx]

      interpolate(t1, v1, t2, v2, time)
    end

    private

    def interpolate(t1, v1, t2, v2, t)
      # Normalized position between keyframes (0.0 to 1.0)
      delta = t2 - t1
      return v1 if delta == 0

      mu = DSP.clamp((t - t1) / delta, 0.0, 1.0)

      case @mode
      when :step
        v1  # Hold until next keyframe
      when :linear
        v1 + (v2 - v1) * mu
      when :exponential
        # Exponential interpolation (good for frequency sweeps)
        # Avoid issues with negative/zero values
        if v1 > 0 && v2 > 0
          v1 * (v2 / v1) ** mu
        elsif v1 < 0 && v2 < 0
          -((-v1) * ((-v2) / (-v1)) ** mu)
        else
          # Fall back to linear if signs differ or zero
          v1 + (v2 - v1) * mu
        end
      when :cubic
        # Cubic hermite interpolation (smooth curves)
        mu2 = mu * mu
        mu3 = mu2 * mu
        a0 = v2 - v1
        v1 + a0 * (3.0 * mu2 - 2.0 * mu3)
      end
    end
  end

  # Enhanced LFO with multiple waveforms and ranges
  class LFO < ModSource
    attr_accessor :depth, :offset
    attr_reader :generator

    # Create LFO with a specific waveform
    # waveform can be :sine, :triangle, :saw, :square, or a custom Generator
    def initialize(waveform: :sine, rate: 1.0, depth: 1.0, offset: 0.0, phase: nil)
      @generator = case waveform
                   when :sine
                     # Use Phasor + sine shaping
                     SineLFO.new(rate, phase)
                   when :triangle
                     Tri.new(rate)
                   when :saw
                     Phasor.new(rate, phase)
                   when :square
                     Pulse.new(rate)
                   when Generator
                     # Custom generator
                     waveform
                   else
                     raise ArgumentError, "Unknown waveform: #{waveform}"
                   end

      @rate = rate
      @depth = depth
      @offset = offset
      @generator.freq = rate if @generator.respond_to?(:freq=)
    end

    def rate
      @rate
    end

    def tick
      # LFO output: oscillator is typically -1 to +1 or 0 to 1
      # Scale by depth and add offset
      @offset + @depth * @generator.tick
    end

    # Update generator frequency when rate changes
    def rate=(val)
      @rate = val
      @generator.freq = val if @generator.respond_to?(:freq=)
    end

    # Convenience methods for common waveforms
    def self.sine(rate: 1.0, depth: 1.0, offset: 0.0)
      new(waveform: :sine, rate: rate, depth: depth, offset: offset)
    end

    def self.triangle(rate: 1.0, depth: 1.0, offset: 0.0)
      new(waveform: :triangle, rate: rate, depth: depth, offset: offset)
    end

    def self.saw(rate: 1.0, depth: 1.0, offset: 0.0)
      new(waveform: :saw, rate: rate, depth: depth, offset: offset)
    end

    def self.square(rate: 1.0, depth: 1.0, offset: 0.0)
      new(waveform: :square, rate: rate, depth: depth, offset: offset)
    end
  end

  # Internal sine LFO generator
  class SineLFO < Phasor
    include DSP::Math

    def tick
      sin(super * TWO_PI)
    end
  end

  # Modulated parameter wrapper
  # Wraps a parameter and applies modulation sources to it
  class ModulatedParam
    attr_reader :base_value, :sources
    attr_accessor :target

    def initialize(target, param_name, base_value = 0.0)
      @target = target
      @param_name = param_name
      @base_value = base_value
      @sources = []  # Array of modulation sources
    end

    # Add a modulation source
    def add_source(source)
      @sources << source unless @sources.include?(source)
      self
    end

    alias_method :<<, :add_source

    # Remove a modulation source
    def remove_source(source)
      @sources.delete(source)
      self
    end

    # Set the base value (what value would be without modulation)
    def base_value=(val)
      @base_value = val
      update_target
    end

    # Calculate current value with all modulation applied
    def value
      mod_sum = @sources.sum { |src| src.tick }
      @base_value + mod_sum
    end

    # Update the target parameter with modulated value
    def update_target
      @target.send("#{@param_name}=", value) if @target
    end

    # Tick all sources and update target
    def tick
      update_target
      value
    end

    # DSL for adding scaled modulation
    def modulate_by(source, depth: 1.0)
      add_source(source.scale(depth))
      self
    end
  end

  # Modulation matrix for managing multiple sources and destinations
  class ModMatrix
    def initialize
      @connections = []  # Array of [source, target, param_name, depth]
    end

    # Connect a modulation source to a parameter
    # Example: matrix.connect(lfo, filter, :freq, depth: 100)
    def connect(source, target, param_name, depth: 1.0)
      @connections << {
        source: source,
        target: target,
        param: param_name,
        depth: depth,
        original_value: target.send(param_name)
      }
      self
    end

    # Remove a connection
    def disconnect(source, target, param_name)
      @connections.reject! do |conn|
        conn[:source] == source &&
        conn[:target] == target &&
        conn[:param] == param_name
      end
      self
    end

    # Update all connections (call this in your audio loop)
    def tick
      # Group connections by target and parameter
      grouped = @connections.group_by { |c| [c[:target], c[:param]] }

      grouped.each do |(target, param), conns|
        # Sum all modulation for this parameter
        mod_sum = conns.sum { |c| c[:source].tick * c[:depth] }

        # Apply to target (add to original value)
        original = conns.first[:original_value]
        target.send("#{param}=", original + mod_sum)
      end
    end

    # Update original values (call when you manually change a parameter)
    def update_base_value(target, param_name, value)
      @connections.each do |conn|
        if conn[:target] == target && conn[:param] == param_name
          conn[:original_value] = value
        end
      end
    end

    # Clear all connections
    def clear!
      @connections.clear
    end

    # Get all connections
    def connections
      @connections.dup
    end
  end

end
