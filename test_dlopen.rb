#!/usr/bin/env ruby
require 'fiddle'

path = File.expand_path('lib/radspberry_audio/radspberry_audio.bundle', __dir__)
puts "Loading: #{path}"
puts "Exists: #{File.exist?(path)}"
$stdout.flush

begin
  handle = Fiddle.dlopen(path)
  puts "Loaded successfully!"
  puts "Handle: #{handle}"
rescue => e
  puts "Error: #{e.class}: #{e.message}"
end
