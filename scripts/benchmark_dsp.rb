require 'benchmark'
require 'matrix'
require_relative '../lib/radspberry'

# Mock sample rate if device init fails or to ensure consistency
DSP::Base.sample_rate = 44100

include DSP

puts "Starting Benchmarks..."

SAMPLES = 44100 * 2 # 2 seconds

# 1. DualRPMOscillator Benchmark
osc = DualRPMOscillator.new(440)
time_osc = Benchmark.realtime do
  SAMPLES.times { osc.tick }
end
puts "DualRPMOscillator: #{SAMPLES / time_osc} samples/sec"

# 2. Math.sin vs DSP::Math.sin
time_std_sin = Benchmark.realtime do
  SAMPLES.times { |i| ::Math.sin(i * 0.01) }
end
puts "Standard Math.sin: #{SAMPLES / time_std_sin} ops/sec"

time_dsp_sin = Benchmark.realtime do
  SAMPLES.times { |i| DSP::Math.sin(i * 0.01) }
end
puts "DSP::Math.sin (Lookup): #{SAMPLES / time_dsp_sin} ops/sec"

# 3. Curvable#apply_curve
class TestCurvable
  include Curvable
  def initialize; @curve = :exponential; end
end
curvable = TestCurvable.new
time_curvable = Benchmark.realtime do
  SAMPLES.times { |i| curvable.apply_curve(0.5, :up) }
end
puts "Curvable#apply_curve (current): #{SAMPLES / time_curvable} ops/sec"

# 4. Phase wrapping
phase = 1.1
time_floor = Benchmark.realtime do
  SAMPLES.times { phase -= phase.floor }
end
puts "Phase wrap (floor): #{SAMPLES / time_floor} ops/sec"

time_if = Benchmark.realtime do
  SAMPLES.times { phase -= 1.0 if phase >= 1.0 }
end
puts "Phase wrap (if): #{SAMPLES / time_if} ops/sec"
