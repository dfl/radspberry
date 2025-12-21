#!/usr/bin/env ruby
puts "1. Loading native extension..."
$stdout.flush

require_relative 'lib/radspberry_audio/radspberry_audio'
puts "2. Native extension loaded"
$stdout.flush

puts "3. Starting NativeAudio..."
$stdout.flush
NativeAudio.start(44100)
puts "4. NativeAudio started"
$stdout.flush

puts "5. Pushing silence..."
$stdout.flush
NativeAudio.push(Array.new(1024, 0.0))
puts "6. Pushed"
$stdout.flush

sleep 0.1

puts "7. Stopping..."
$stdout.flush
NativeAudio.stop
puts "8. Done!"
