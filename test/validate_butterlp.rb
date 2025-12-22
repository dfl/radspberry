require_relative '../lib/radspberry'
include DSP

# Set sample rate to user's 96k environment
Base.sample_rate = 96000

def test_lp(f, q)
  lp = ButterLP.new(f, q: q)
  # Force recalc to ensure coeffs are set
  lp.freq = f
  
  b, a = lp.b, lp.a
  puts "\nTesting ButterLP at #{f}Hz (srate: #{Base.sample_rate})"
  puts "Coeffs: b=#{b.map{|x| x.round(6)}}, a=#{a.map{|x| x.round(6)}}"
  
  # Check DC gain (should be 1.0)
  dc_gain = b.sum / a.sum
  puts "DC Gain: #{dc_gain.round(4)}"
  
  # Check Nyquist gain (should be 0 for LP)
  # H(z=-1) = (b0 - b1 + b2) / (a0 - a1 + a2)
  nyq_gain = (b[0] - b[1] + b[2]) / (a[0] - a[1] + a[2])
  puts "Nyquist Gain: #{nyq_gain.round(6)}"
end

test_lp(1000, 0.707)
test_lp(5000, 0.707)
test_lp(20000, 0.707)
test_lp(40000, 0.707) # Near Nyquist (48k)
