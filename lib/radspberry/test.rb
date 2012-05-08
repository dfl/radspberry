require './dsp'
require './speaker'
require './super_saw'

chain = XFader[ o1=SuperSaw.new, o2=RpmNoise.new ]
Speaker[ chain ]
o1.spread = 0.8
chain.fade = 0

# Speaker.mute

