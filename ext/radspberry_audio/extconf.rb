require 'mkmf'

# Cross-platform PortAudio detection
case RbConfig::CONFIG['host_os']
when /darwin/
  # macOS: try Homebrew first
  portaudio_prefix = `brew --prefix portaudio 2>/dev/null`.chomp
  if File.directory?(portaudio_prefix)
    $CFLAGS << " -I#{portaudio_prefix}/include"
    $LDFLAGS << " -L#{portaudio_prefix}/lib"
  end
when /linux/
  # Linux: pkg-config or standard paths
  pkg_config('portaudio-2.0') rescue nil
when /mswin|mingw/
  # Windows: check common install paths
  ['C:/portaudio', 'C:/Program Files/portaudio'].each do |path|
    if File.directory?(path)
      $CFLAGS << " -I#{path}/include"
      $LDFLAGS << " -L#{path}/lib"
      break
    end
  end
end

have_library('portaudio') or abort <<~MSG
  PortAudio not found. Install it:
    macOS:   brew install portaudio
    Ubuntu:  sudo apt install libportaudio2 portaudio19-dev
    Windows: download from http://www.portaudio.com
MSG

have_header('portaudio.h') or abort "portaudio.h not found"

create_makefile('radspberry_audio/radspberry_audio')
