module DSP
  class Sampler < Generator
    
    attr_accessor :loop, :rate, :pos, :volume
    attr_reader :buffer, :duration
    
    def initialize(file_path = nil, opts = {})
      @buffer = []
      @rate = opts.fetch(:rate, 1.0)
      @volume = opts.fetch(:volume, 1.0)
      @loop = opts.fetch(:loop, false)
      @pos = 0.0
      @duration = 0.0
      @rate_compensation = 1.0
      load_file(file_path) if file_path
    end
    
    def load_file(path)
      return unless File.exist?(path)
      
      # Use a specific format to ensure we get floats in -1.0..1.0 range
      # wavefile gem can convert on the fly if we specify the format in the reader
      format = WaveFile::Format.new(:mono, :float, @srate || 44100)
      
      reader = WaveFile::Reader.new(path, format)
      @native_srate = reader.native_format.sample_rate
      @rate_compensation = @native_srate.to_f / srate

      reader.each_buffer(1024) do |buffer|
        @buffer.concat(buffer.samples)
      end
      
      @duration = @buffer.size.to_f / @native_srate
    end
    
    def trigger!
      @pos = 0.0
    end
    
    def tick
      return 0.0 if @buffer.empty?
      
      # Integer index
      idx = @pos.to_i
      
      if idx >= @buffer.size
        if @loop
          @pos %= @buffer.size
          idx = @pos.to_i
        else
          return 0.0
        end
      elsif idx < 0
        return 0.0
      end
      
      # Linear interpolation for better sound quality when pitch shifting
      i1 = idx
      i2 = (idx + 1) % @buffer.size
      frac = @pos - i1
      
      s1 = @buffer[i1]
      s2 = @buffer[i2]
      
      sample = s1 + frac * (s2 - s1)
      
      @pos += @rate * @rate_compensation
      
      sample * @volume
    end
    
    def length
      @buffer.size
    end
    
    def finished?
      !@loop && @pos >= @buffer.size
    end
  end
end
