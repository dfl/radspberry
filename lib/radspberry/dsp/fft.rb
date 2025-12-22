# Fast Fourier Transform - Radix-2 Cooley-Tukey implementation

module DSP
  module FFT
    extend self

    # Forward FFT: time domain -> frequency domain
    # Input: Array of real or complex samples (length must be power of 2)
    # Output: Array of Complex values
    def fft(x)
      n = x.size
      return x.map { |v| Complex(v, 0) } if n <= 1
      raise ArgumentError, "Size must be power of 2, got #{n}" unless power_of_2?(n)

      transform(x, false)
    end

    # Inverse FFT: frequency domain -> time domain
    # Input: Array of Complex values
    # Output: Array of Complex values (take .real for real signal)
    def ifft(x)
      n = x.size
      return x if n <= 1
      raise ArgumentError, "Size must be power of 2, got #{n}" unless power_of_2?(n)

      result = transform(x, true)
      inv_n = 1.0 / n
      result.map { |c| c * inv_n }
    end

    # Compute magnitude spectrum in dB (normalized to 0 dB peak)
    def magnitude_db(fft_result, floor: -120.0)
      mags = fft_result.map(&:abs)
      max_mag = mags.max
      return Array.new(mags.size, floor) if max_mag == 0

      mags.map { |m| m > 0 ? [20 * ::Math.log10(m / max_mag), floor].max : floor }
    end

    # Compute magnitude spectrum (linear)
    def magnitude(fft_result)
      fft_result.map(&:abs)
    end

    # Compute phase spectrum (radians)
    def phase(fft_result)
      fft_result.map { |c| ::Math.atan2(c.imag, c.real) }
    end

    # Apply Hann window to samples
    def hann_window(samples)
      n = samples.size
      samples.each_with_index.map { |s, i|
        s * (0.5 - 0.5 * ::Math.cos(2 * ::Math::PI * i / n))
      }
    end

    # Apply Hamming window
    def hamming_window(samples)
      n = samples.size
      samples.each_with_index.map { |s, i|
        s * (0.54 - 0.46 * ::Math.cos(2 * ::Math::PI * i / n))
      }
    end

    # Apply Blackman window
    def blackman_window(samples)
      n = samples.size
      samples.each_with_index.map { |s, i|
        s * (0.42 - 0.5 * ::Math.cos(2 * ::Math::PI * i / n) + 0.08 * ::Math.cos(4 * ::Math::PI * i / n))
      }
    end

    # Bin index to frequency
    def bin_to_freq(bin, fft_size, sample_rate)
      bin * sample_rate.to_f / fft_size
    end

    # Frequency to bin index
    def freq_to_bin(freq, fft_size, sample_rate)
      (freq * fft_size / sample_rate.to_f).round
    end

    # Find peaks in magnitude spectrum
    # Returns array of {bin:, freq:, db:} sorted by magnitude
    def find_peaks(fft_result, sample_rate, threshold_db: -40)
      db = magnitude_db(fft_result)
      n = fft_result.size
      half_n = n / 2

      peaks = []
      (1...half_n - 1).each do |i|
        if db[i] > threshold_db && db[i] > db[i - 1] && db[i] > db[i + 1]
          peaks << {
            bin: i,
            freq: bin_to_freq(i, n, sample_rate),
            db: db[i]
          }
        end
      end

      peaks.sort_by { |p| -p[:db] }
    end

    # Analyze a signal: apply window, FFT, find peaks
    def analyze(samples, sample_rate, window: :hann, threshold_db: -40)
      windowed = case window
                 when :hann then hann_window(samples)
                 when :hamming then hamming_window(samples)
                 when :blackman then blackman_window(samples)
                 when :none, nil then samples
                 else raise ArgumentError, "Unknown window: #{window}"
                 end

      result = fft(windowed)
      {
        fft: result,
        magnitude_db: magnitude_db(result),
        peaks: find_peaks(result, sample_rate, threshold_db: threshold_db),
        sample_rate: sample_rate,
        fft_size: samples.size,
        bin_resolution: sample_rate.to_f / samples.size
      }
    end

    private

    def power_of_2?(n)
      n > 0 && (n & (n - 1)) == 0
    end

    def transform(x, inverse)
      n = x.size
      m = ::Math.log2(n).to_i

      # Convert to complex
      result = x.map { |v| v.is_a?(Complex) ? v : Complex(v, 0) }

      # Bit-reversal permutation
      (0...n).each do |i|
        j = bit_reverse(i, m)
        result[i], result[j] = result[j], result[i] if j > i
      end

      # Cooley-Tukey iterative FFT
      len = 2
      while len <= n
        angle = (inverse ? 2 : -2) * ::Math::PI / len
        wlen = Complex(::Math.cos(angle), ::Math.sin(angle))

        (0...n).step(len) do |i|
          w = Complex(1, 0)
          (0...len / 2).each do |j|
            u = result[i + j]
            t = w * result[i + j + len / 2]
            result[i + j] = u + t
            result[i + j + len / 2] = u - t
            w *= wlen
          end
        end
        len *= 2
      end

      result
    end

    def bit_reverse(x, bits)
      result = 0
      bits.times do
        result = (result << 1) | (x & 1)
        x >>= 1
      end
      result
    end
  end
end
