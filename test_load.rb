#!/usr/bin/env ruby
puts "1. Loading library..."
$stdout.flush

require_relative 'lib/radspberry'
puts "2. Library loaded"
$stdout.flush

include DSP
puts "3. DSP included"
$stdout.flush

puts "4. Creating voice..."
$stdout.flush
v = Voice.acid
puts "5. Voice created"
$stdout.flush

puts "All done!"
