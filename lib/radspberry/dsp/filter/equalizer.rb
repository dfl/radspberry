module DSP
  # Multi-band Equalizer using SuperParametricEQ
  # Defaults to 4-band console style topology
  class Equalizer < Processor
    attr_reader :bands

    def initialize(num_bands = 4)
      @bands = Array.new(num_bands) { SuperParametricEQ.new }
    end

    def tick(input)
      @bands.each { |band| input = band.tick(input) }
      input
    end

    def clear!
      @bands.each(&:clear!)
    end

    def character=(p)
      @bands.each { |b| b.preset = p }
    end
  end
end
