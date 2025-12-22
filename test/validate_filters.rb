require_relative '../lib/radspberry'
include DSP
include Math

Base.sample_rate = 96000

def check_gain(name, filter, test_freq)
  b, a = filter.b, filter.a
  w0 = 2 * PI * test_freq / Base.sample_rate
  z_inv = Complex(cos(w0), -sin(w0))
  z_inv2 = z_inv * z_inv
  
  num = b[0] + b[1] * z_inv + b[2] * z_inv2
  den = a[0] + a[1] * z_inv + a[2] * z_inv2
  
  gain = num.abs / den.abs
  return (20 * log10(gain)).round(2)
end

def audit_filter(klass, f, q, gain: 0.0)
  filter = klass.new(f, q: q)
  filter.gain = gain if filter.respond_to?(:gain=)
  filter.freq = f
  
  puts "\nAudit: #{klass.name} at #{f}Hz (Q=#{q}, G=#{gain})"
  puts "  Gain at DC (10Hz):    #{check_gain(klass.name, filter, 10)} dB"
  puts "  Gain at Cutoff (#{f}Hz):  #{check_gain(klass.name, filter, f)} dB"
  puts "  Gain at Nyquist (48k): #{check_gain(klass.name, filter, 47990)} dB"
end

def audit_super_eq(f, gain, symmetry, q: 0.707)
  filter = SuperParametricEQ.new(f, gain, q)
  filter.symmetry = symmetry
  
  puts "\nAudit: SuperParametricEQ at #{f}Hz (Q=#{q}, G=#{gain}, Symm=#{symmetry})"
  puts "  Gain at DC (10Hz):    #{check_gain("SuperEQ", filter, 10)} dB"
  puts "  Gain at Cutoff (#{f}Hz):  #{check_gain("SuperEQ", filter, f)} dB"
  puts "  Gain at Nyquist (48k): #{check_gain("SuperEQ", filter, 47990)} dB"
end

audit_filter(ButterLP, 1000, 0.707)
audit_filter(ButterHP, 1000, 0.707)
audit_filter(ButterBP, 1000, 1.0)
audit_filter(ButterNotch, 1000, 1.0)

audit_super_eq(1000, 12.0, 0.0, q: 1.0)  # Bell
audit_super_eq(1000, 12.0, -1.0, q: 0.707) # Low Shelf
audit_super_eq(1000, 12.0, 1.0, q: 0.707)  # High Shelf
