require 'mkmf'

# Find PortAudio (Homebrew on macOS)
portaudio_prefix = `brew --prefix portaudio 2>/dev/null`.chomp
if File.directory?(portaudio_prefix)
  $CFLAGS << " -I#{portaudio_prefix}/include"
  $LDFLAGS << " -L#{portaudio_prefix}/lib"
end

have_library('portaudio') or abort "PortAudio not found. Install with: brew install portaudio"
have_header('portaudio.h') or abort "portaudio.h not found"

create_makefile('radspberry_audio/radspberry_audio')
