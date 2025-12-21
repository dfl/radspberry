#!/usr/bin/env ruby
# Demo: Native C Extension vs FFI Callback Audio
#
# This script demonstrates how the native C extension prevents glitches
# by running the audio callback entirely in C (no GVL needed).
#
# Usage: ruby examples/buffered_demo.rb

require_relative '../lib/radspberry'
include DSP

def heavy_ruby_work
  print "hogging GVL for ~2 seconds straight..."

  10.times do
    result = 0
    1500.times do |a|
      1500.times do |b|
        result += (a * b) % 127
      end
    end
  end

  puts "done"
end

def run_ffi_demo
  puts "\n#{"="*60}"
  puts "  FFI CALLBACK MODE (Ruby callback needs GVL)"
  puts "="*60

  osc = SuperSaw.new(110)
  Speaker.new(osc, volume: 0.3, frameSize: 512)

  puts "Playing audio..."
  sleep 0.5

  start_time = Time.now
  heavy_ruby_work
  elapsed = Time.now - start_time

  puts "\nHeavy work took #{elapsed.round(1)}s"

  sleep 0.5
  Speaker.mute
  sleep 0.2

  # Must close FFI stream before native can use PortAudio
  FFI::PortAudio::API.Pa_Terminate rescue nil
end

def run_native_demo
  puts "\n#{"="*60}"
  puts "  NATIVE C CALLBACK (no GVL needed!)"
  puts "="*60

  osc = SuperSaw.new(110)
  NativeSpeaker.new(osc, volume: 0.3)

  puts "Playing audio... (buffer: #{(NativeSpeaker.buffer_level * 100).round}%)"
  sleep 0.5

  start_time = Time.now
  heavy_ruby_work
  elapsed = Time.now - start_time

  puts "\nHeavy work took #{elapsed.round(1)}s"
  puts "Buffer level: #{(NativeSpeaker.buffer_level * 100).round}%"

  sleep 0.5
  NativeSpeaker.stop
  sleep 0.2
end

puts <<~BANNER

  ╔════════════════════════════════════════════════════════════╗
  ║         RADSPBERRY AUDIO STABILITY DEMO                    ║
  ║                                                            ║
  ║  FFI callback vs Native C extension                        ║
  ╚════════════════════════════════════════════════════════════╝

BANNER

puts "Press ENTER to start FFI demo (expect glitches)..."
gets

run_ffi_demo

puts "\n\nPress ENTER to start NATIVE demo (should be smooth!)..."
gets

run_native_demo

puts <<~SUMMARY

  ╔════════════════════════════════════════════════════════════╗
  ║  DEMO COMPLETE                                             ║
  ║                                                            ║
  ║  FFI mode: PortAudio calls Ruby, needs GVL, glitches.      ║
  ║                                                            ║
  ║  Native mode: C callback reads from ring buffer directly,  ║
  ║  never touches Ruby/GVL. Producer thread feeds buffer.     ║
  ╚════════════════════════════════════════════════════════════╝

SUMMARY
