#!/usr/bin/env ruby
puts "1. Starting..."
$stdout.flush

puts "2. Requiring ffi-portaudio..."
$stdout.flush
require 'ffi-portaudio'
puts "3. ffi-portaudio loaded"
$stdout.flush

puts "4. Initializing Pa..."
$stdout.flush
FFI::PortAudio::API.Pa_Initialize
puts "5. Pa initialized"
$stdout.flush

puts "6. Getting default device..."
$stdout.flush
device = FFI::PortAudio::API.Pa_GetDefaultOutputDevice
puts "7. Device: #{device}"
$stdout.flush

puts "8. Terminating Pa..."
$stdout.flush
FFI::PortAudio::API.Pa_Terminate
puts "9. Done!"
