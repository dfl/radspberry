#!/usr/bin/env ruby
require_relative 'lib/radspberry'
include DSP

puts "Test 1: Single voice play/stop"
v = Voice.acid
puts "  Created voice"
Speaker.play(v, volume: 0.3)
puts "  Started playing"
v.play(:a2)
puts "  Playing note..."
sleep 0.3
v.stop
puts "  Stopped note"
sleep 0.1
Speaker.stop
puts "  Stopped speaker"
puts "  OK!"

sleep 0.2

puts "\nTest 2: Second voice"
v2 = Voice.pluck
puts "  Created voice"
Speaker.play(v2, volume: 0.3)
puts "  Started playing"
v2.play(:c3)
puts "  Playing note..."
sleep 0.3
v2.stop
puts "  Stopped note"
sleep 0.1
Speaker.stop
puts "  Stopped speaker"
puts "  OK!"

puts "\nAll tests passed!"
