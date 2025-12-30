module DSP

  # IIR Hilbert transformer using 6-stage second-order allpass filters
  # Provides ~90° phase difference across audio band for SSB frequency shifting
  #
  # Based on proven coefficients from SDR implementations
  #
  class HilbertIIR
    # Raw coefficients (will be squared for use)
    C_HI = [0.5131884, 0.8133175, 0.9359722, 0.9791145, 0.9934793, 0.9989305]
    C_LO = [0.2755710, 0.6922636, 0.8896328, 0.9633075, 0.9882633, 0.9965990]
    STAGES = 6

    def initialize
      # Squared coefficients
      @a_hi = C_HI.map { |c| c * c }
      @a_lo = C_LO.map { |c| c * c }

      # Allpass states: [input_delay, output_delay] for each stage
      @state_hi_i = Array.new(STAGES) { [0.0, 0.0] }
      @state_hi_o = Array.new(STAGES) { [0.0, 0.0] }
      @state_lo_i = Array.new(STAGES) { [0.0, 0.0] }
      @state_lo_o = Array.new(STAGES) { [0.0, 0.0] }

      # One-sample delay for hi path
      @hi_delay = 0.0
    end

    def clear!
      STAGES.times do |i|
        @state_hi_i[i] = [0.0, 0.0]
        @state_hi_o[i] = [0.0, 0.0]
        @state_lo_i[i] = [0.0, 0.0]
        @state_lo_o[i] = [0.0, 0.0]
      end
      @hi_delay = 0.0
    end

    # Process one sample, returns [I, Q] where Q is ~90° shifted
    def tick(input)
      # High path (processes input directly)
      hi_in = input
      STAGES.times do |m|
        # Second-order allpass: y = a*(x + y[n-2]) - x[n-2]
        hi_out = @a_hi[m] * (hi_in + @state_hi_o[m][1]) - @state_hi_i[m][1]

        # Advance delays
        @state_hi_i[m][1] = @state_hi_i[m][0]
        @state_hi_i[m][0] = hi_in
        @state_hi_o[m][1] = @state_hi_o[m][0]
        @state_hi_o[m][0] = hi_out

        hi_in = hi_out
      end

      # One-sample delay on hi output
      i_out = @hi_delay
      @hi_delay = hi_in

      # Low path (processes input directly)
      lo_in = input
      STAGES.times do |m|
        lo_out = @a_lo[m] * (lo_in + @state_lo_o[m][1]) - @state_lo_i[m][1]

        @state_lo_i[m][1] = @state_lo_i[m][0]
        @state_lo_i[m][0] = lo_in
        @state_lo_o[m][1] = @state_lo_o[m][0]
        @state_lo_o[m][0] = lo_out

        lo_in = lo_out
      end
      q_out = lo_in

      [i_out, q_out]
    end
  end

  # SSB Frequency Shifter using IIR Hilbert transformer
  # Shifts all frequencies by a fixed amount while preserving spectrum shape
  #
  class FreqShifterSSB
    include DSP::Math

    attr_accessor :shift_hz

    def initialize(shift_hz = 0.0, sample_rate = 48000.0)
      @hilbert = HilbertIIR.new
      @shift_hz = shift_hz
      @sample_rate = sample_rate
      @phase = 0.0
    end

    def clear!
      @hilbert.clear!
      @phase = 0.0
    end

    def sample_rate=(rate)
      @sample_rate = rate
    end

    # Process one sample, returns frequency-shifted output
    def tick(input)
      i, q = @hilbert.tick(input)

      # SSB modulation: upshift = I*cos + Q*sin
      c = ::Math.cos(@phase)
      s = ::Math.sin(@phase)
      output = i * c + q * s

      # Advance phase
      @phase += 2.0 * ::Math::PI * @shift_hz / @sample_rate
      @phase -= 2.0 * ::Math::PI if @phase >= 2.0 * ::Math::PI
      @phase += 2.0 * ::Math::PI if @phase < 0.0

      output
    end

    # For convenience: upper sideband (positive shift)
    def tick_usb(input)
      i, q = @hilbert.tick(input)
      i - q
    end

    # For convenience: lower sideband (negative shift)
    def tick_lsb(input)
      i, q = @hilbert.tick(input)
      i + q
    end
  end

end
