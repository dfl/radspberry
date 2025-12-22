# Thread-safe envelopes - using state-machine semantics instead of Fibers
# to support cross-thread calls from NativeSpeaker.

module DSP
  class ADEnvelope < Generator
    include Curvable
    attr_accessor :attack, :decay

    IDLE = 0
    ATTACK = 1
    DECAY = 2

    def initialize(attack: 0.01, decay: 0.1, curve: :linear)
      @attack = attack
      @decay = decay
      @curve = curve
      @state = IDLE
      @current_sample = 0
      @current_value = 0.0
    end

    def trigger!
      @state = ATTACK
      @current_sample = 0
      @attack_samples = (@attack * srate).to_i
      @decay_samples = (@decay * srate).to_i
    end

    def tick
      case @state
      when ATTACK
        if @current_sample < @attack_samples
          @current_value = apply_curve(@current_sample.to_f / @attack_samples, :up)
          @current_sample += 1
        else
          @state = DECAY
          @current_sample = 0
        end
      when DECAY
        if @current_sample < @decay_samples
          @current_value = apply_curve(1.0 - @current_sample.to_f / @decay_samples, :down)
          @current_sample += 1
        else
          @state = IDLE
          @current_value = 0.0
        end
      else
        @current_value = 0.0
      end
      @current_value
    end

    def srate=(rate)
      super
      trigger! if @state != IDLE
    end
  end


  class ADSREnvelope < Generator
    include Curvable
    attr_accessor :attack, :decay, :sustain, :release

    IDLE = 0
    ATTACK = 1
    DECAY = 2
    SUSTAIN = 3
    RELEASE = 4

    def initialize(attack: 0.01, decay: 0.1, sustain: 0.7, release: 0.2, curve: :linear)
      @attack = attack
      @decay = decay
      @sustain = sustain
      @release = release
      @curve = curve
      @state = IDLE
      @gate = false
      @current_value = 0.0
      @current_sample = 0
    end

    def gate_on!
      @gate = true
      @state = ATTACK
      @current_sample = 0
      recalc!
    end

    def gate_off!
      @gate = false
      if @state != IDLE
        @state = RELEASE
        @release_from = @current_value
        @current_sample = 0
      end
    end

    def trigger!
      gate_on!
    end

    def tick
      case @state
      when ATTACK
        if @current_sample < @attack_samples
          @current_value = apply_curve(@current_sample.to_f / @attack_samples, :up)
          @current_sample += 1
        else
          @state = DECAY
          @current_sample = 0
        end
      when DECAY
        if @current_sample < @decay_samples
          level = 1.0 - (1.0 - @sustain) * (@current_sample.to_f / @decay_samples)
          @current_value = level
          @current_sample += 1
        else
          @state = SUSTAIN
        end
      when SUSTAIN
        @current_value = @sustain
        gate_off! unless @gate
      when RELEASE
        if @current_sample < @release_samples
          ratio = @current_sample.to_f / @release_samples
          level = @release_from * (1.0 - ratio)
          @current_value = apply_curve(level, :down)
          @current_sample += 1
        else
          @state = IDLE
          @current_value = 0.0
        end
      else
        @current_value = 0.0
      end
      @current_value
    end

    def srate=(rate)
      super
      recalc!
    end

    private
    
    def recalc!
      @attack_samples = (@attack * srate).to_i
      @decay_samples = (@decay * srate).to_i
      @release_samples = (@release * srate).to_i
    end
  end
end
