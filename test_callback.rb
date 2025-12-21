#!/usr/bin/env ruby
# Test without native extension

# Prevent loading native extension
module NativeAudioBlocker
  def require(path)
    if path.include?('radspberry_audio')
      puts "Skipping native extension load"
      return false
    end
    super
  end
end
Object.prepend(NativeAudioBlocker)

puts "1. Loading library..."
$stdout.flush

require_relative 'lib/radspberry'
puts "2. Library loaded"
$stdout.flush

include DSP
puts "3. DSP included"
$stdout.flush

puts "4. Native available? #{Speaker.native_available?}"
$stdout.flush

puts "5. Creating voice..."
$stdout.flush
v = Voice.acid
puts "6. Voice created"
$stdout.flush

puts "7. Playing (callback mode)..."
$stdout.flush
Speaker.play(v, volume: 0.3, buffered: false)
v.play(:a2)
sleep 0.5
v.stop
sleep 0.2
Speaker.stop
puts "8. Done!"
