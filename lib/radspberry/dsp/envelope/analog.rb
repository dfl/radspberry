# Analog-style ADSR using exponential RC curves
# Based on Will Pirkle / EarLevel Engineering method

module DSP
  class AnalogEnvelope < Generator
    IDLE = 0
    ATTACK = 1
    DECAY = 2
    SUSTAIN = 3
    RELEASE = 4

    attr_reader :state, :output, :attack_time, :decay_time, :sustain_level, :release_time

    def attack=(t); @attack_time = t; recalc_coefficients!; end
    def decay=(t); @decay_time = t; recalc_coefficients!; end
    def sustain=(l); @sustain_level = l; recalc_coefficients!; end
    def release=(t); @release_time = t; recalc_coefficients!; end

    alias_method :attack_time=, :attack=
    alias_method :decay_time=, :decay=
    alias_method :sustain_level=, :sustain=
    alias_method :release_time=, :release=

    alias_method :attack, :attack_time
    alias_method :decay, :decay_time
    alias_method :sustain, :sustain_level
    alias_method :release, :release_time

    # TCO = Target Coefficient Overshoot
    DEFAULT_TCO_ATTACK = 0.3
    DEFAULT_TCO_DECAY = 0.0001

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
      @state = RELEASE if @state != IDLE
    end

    def gate=(val)
      val ? gate_on! : gate_off!
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
      attack_samples = [@attack_time * srate, 1].max
      @attack_coef = calc_coef(attack_samples, @tco_attack)
      @attack_base = (1.0 + @tco_attack) * (1.0 - @attack_coef)

      decay_samples = [@decay_time * srate, 1].max
      @decay_coef = calc_coef(decay_samples, @tco_decay)
      @decay_base = (@sustain_level - @tco_decay) * (1.0 - @decay_coef)

      release_samples = [@release_time * srate, 1].max
      @release_coef = calc_coef(release_samples, @tco_decay)
      @release_base = -@tco_decay * (1.0 - @release_coef)
    end

    def calc_coef(rate, tco)
      ::Math.exp(-::Math.log((1.0 + tco) / tco) / rate)
    end
  end


  class AnalogADEnvelope < AnalogEnvelope
    def initialize(attack: 0.01, decay: 0.3, **opts)
      super(attack: attack, decay: decay, sustain: 0.0, release: 0.001, **opts)
    end

    def gate_on!
      @state = ATTACK
      recalc_coefficients!
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
        if @output <= 0.0001
          @output = 0.0
          @state = IDLE
        end
      end

      @output
    end
  end
end
