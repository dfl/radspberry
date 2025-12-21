# Fiber-based envelopes - natural state-machine semantics

module DSP
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

        attack_samples.times do |i|
          Fiber.yield(apply_curve(i.to_f / attack_samples, :up))
        end

        decay_samples.times do |i|
          Fiber.yield(apply_curve(1.0 - i.to_f / decay_samples, :down))
        end

        loop { Fiber.yield(0.0) }
      end
    end

    private

    def apply_curve(value, direction)
      case @curve
      when :linear then value
      when :exponential
        direction == :up ? value ** 2 : value ** 0.5
      when :logarithmic
        direction == :up ? value ** 0.5 : value ** 2
      else value
      end
    end
  end


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

        attack_samples.times do |i|
          Fiber.yield(apply_curve(i.to_f / attack_samples, :up))
        end

        decay_samples.times do |i|
          level = 1.0 - (1.0 - @sustain) * (i.to_f / decay_samples)
          Fiber.yield(level)
        end

        Fiber.yield(@sustain) while @gate

        release_samples.times do |i|
          level = @release_from * (1.0 - i.to_f / release_samples)
          Fiber.yield(apply_curve(level, :down))
        end

        loop { Fiber.yield(0.0) }
      end
    end

    private

    def apply_curve(value, direction)
      case @curve
      when :linear then value
      when :exponential
        direction == :up ? value ** 2 : value ** 0.5
      when :logarithmic
        direction == :up ? value ** 0.5 : value ** 2
      else value
      end
    end
  end
end
