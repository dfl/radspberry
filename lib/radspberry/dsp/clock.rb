# Timing and scheduling helpers
# Enables: sleep 1.beat, Clock.bpm = 140, etc.

module Clock
  extend self

  @bpm = 120
  @beats_per_bar = 4

  attr_accessor :bpm, :beats_per_bar

  def beat_duration
    60.0 / @bpm
  end

  def bar_duration
    beat_duration * @beats_per_bar
  end
end


module TimingExtensions
  def beat  = self * Clock.beat_duration
  def beats = beat
  def bar   = self * Clock.bar_duration
  def bars  = bar
  def ms    = self / 1000.0
  def s     = self.to_f
  def second = s
  def seconds = s

  alias_method :b, :beat
end

Numeric.include TimingExtensions
