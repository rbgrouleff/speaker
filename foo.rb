require 'ffi'

module Foo
  extend FFI::Library

  ffi_lib '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation', '/System/Library/Frameworks/CoreServices.framework/CoreServices', '/System/Library/Frameworks/AudioUnit.framework/AudioUnit'

  typedef :uint32, :OSType
  typedef :int32, :OSStatus

  typedef :pointer, :CFTypeRef
  typedef :CFTypeRef, :CFStringRef
  typedef :pointer, :CFAllocatorRef
  typedef :uint32, :CFStringEncoding

  typedef :pointer, :AudioComponent
  typedef :pointer, :AudioUnit
  typedef :pointer, :AudioUnitRef

  typedef :uint32, :AudioUnitPropertyID
  typedef :uint32, :AudioUnitScope
  typedef :uint32, :AudioUnitElement

  StringEncodings = enum :StringEncodings, [
    :UTF8, 0x08000100,
  ]

  class AudioComponentDescription < FFI::Struct
    layout  :componentType, :OSType,
            :componentSubType, :OSType,
            :componentManufacturer, :OSType,
            :componentFlags, :uint32,
            :componentFlagsMask, :uint32
  end

  class AudioStreamBasicDescription < FFI::Struct
    layout  :mSampleRate, :double,
            :mFormatID, :uint32,
            :mFormatFlags, :uint32,
            :mBytesPerPacket, :uint32,
            :mFramesPerPacket, :uint32,
            :mBytesPerFrame, :uint32,
            :mChannelsPerFrame, :uint32,
            :mBitsPerChannel, :uint32,
            :mReserved, :uint32
  end

  attach_function :CFStringCreateWithCString, [:CFAllocatorRef, :string, :CFStringEncoding], :CFStringRef
  attach_function :CFRelease, [:CFTypeRef], :void
  attach_function :UTGetOSTypeFromString, [:CFStringRef], :OSType

  attach_function :AudioComponentFindNext, [:AudioComponent, AudioComponentDescription.by_ref], :AudioComponent
  attach_function :AudioComponentInstanceNew, [:AudioComponent, :AudioUnitRef], :OSStatus
  attach_function :AudioUnitInitialize, [:AudioUnit], :OSStatus

  attach_function :AudioUnitSetProperty, [:AudioUnit, :AudioUnitPropertyID, :AudioUnitScope, :AudioUnitElement, :pointer, :uint32], :OSStatus

  attach_function :AudioOutputUnitStart, [:AudioUnit], :OSStatus

  attach_function :AudioOutputUnitStop, [:AudioUnit], :OSStatus
  attach_function :AudioUnitUninitialize, [:AudioUnit], :OSStatus
  attach_function :AudioComponentInstanceDispose, [:AudioUnit], :OSStatus

  class AudioBuffer < FFI::Struct
    layout  :mNumberChannels, :uint32,
            :mDataByteSize, :uint32,
            :mData, :pointer
  end

  class AudioBufferList < FFI::Struct
    layout  :mNumberBuffers, :uint32,
            :mBuffers, AudioBuffer
  end

  class SoundOutput < FFI::Struct
    layout  :SamplesPerSecond, :double,
            :AudioUnit, :pointer,
            :Frequency, :double,
            :RenderPhase, :double
  end

  callback :AURenderCallback, [SoundOutput.by_ref, :pointer, :pointer, :uint32, :uint32, AudioBufferList.by_ref], :OSStatus

  class AURenderCallbackStruct < FFI::Struct
    layout  :inputProc, :AURenderCallback,
            :inputProcRefCon, :pointer
  end
end

include Foo

stopping = false
Signal.trap('INT') do |signal|
  stopping = true
end

sound_output = SoundOutput.new
sound_output[:SamplesPerSecond] = 48_000.0
sound_output[:Frequency] = 440.0

uti = CFStringCreateWithCString(nil, 'auou', StringEncodings[:UTF8])
output_type = UTGetOSTypeFromString(uti)
CFRelease(uti)

uti = CFStringCreateWithCString(nil, 'def ', StringEncodings[:UTF8])
output_subtype = UTGetOSTypeFromString(uti)
CFRelease(uti)

uti = CFStringCreateWithCString(nil, 'appl', StringEncodings[:UTF8])
output_manufacturer = UTGetOSTypeFromString(uti)
CFRelease(uti)

acd = AudioComponentDescription.new
acd[:componentType] = output_type # AudioComponentType[:output]
acd[:componentSubType] = output_subtype # AudioComponentSubType[:default_output]
acd[:componentManufacturer] = output_manufacturer # AudioComponentManufacturer[:apple]

audio_component = AudioComponentFindNext(nil, acd)

au_ptr = FFI::MemoryPointer.new(:pointer)
au_ptr.write_pointer sound_output[:AudioUnit]
AudioComponentInstanceNew(audio_component, au_ptr)
sound_output[:AudioUnit] = au_ptr.read_pointer
AudioUnitInitialize(sound_output[:AudioUnit])

uti = CFStringCreateWithCString(nil, 'lpcm', StringEncodings[:UTF8])
audio_format = UTGetOSTypeFromString(uti)
CFRelease(uti)

asbd = AudioStreamBasicDescription.new
asbd[:mSampleRate] = sound_output[:SamplesPerSecond]
asbd[:mFormatID] = audio_format # AudioFormat[:linear_pcm]
asbd[:mFormatFlags] = 1 << 0 # LinearPCMFormatFlag[:is_float]
asbd[:mChannelsPerFrame] = 2
asbd[:mFramesPerPacket] = 1
asbd[:mBitsPerChannel] = 1 * FFI.type_size(:float) * 8
asbd[:mBytesPerPacket] = 2 * FFI.type_size(:float)
asbd[:mBytesPerFrame] = 2 * FFI.type_size(:float)

stream_format = 8 # AudioUnitProperty[:stream_format] UTGetOSTypeFromString(uti)
scope = 1 # AudioUnitScope[:input]

AudioUnitSetProperty(sound_output[:AudioUnit], stream_format, scope, 0, asbd.pointer, asbd.size)

cb = AURenderCallbackStruct.new
cb[:inputProc] = FFI::Function.new(Foo.find_type(:OSStatus), [SoundOutput.by_ref, :pointer, :pointer, :uint32, :uint32, AudioBufferList.by_ref]) do |soundOutput, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, audioBufferList|
  phaseStep = soundOutput[:Frequency].fdiv(soundOutput[:SamplesPerSecond]) * (2 * Math::PI)
  samples = inNumberFrames.times.to_a.flat_map { |i|
    val = 0.7 * Math.sin(soundOutput[:RenderPhase])
    soundOutput[:RenderPhase] += phaseStep
    [val, val]
  }

  audioBufferList[:mNumberBuffers].times do |i|
    bufferPointer = audioBufferList[:mBuffers].pointer
    audioBuffer = AudioBuffer.new(bufferPointer + (i * AudioBuffer.size))
    output_buffer = audioBuffer[:mData]
    output_buffer.write_array_of_float samples
  end
  0
end

cb[:inputProcRefCon] = sound_output.pointer

render_callback = 23 # AudioUnitProperty[:set_render_callback]
scope = 0 # AudioUnitScope[:global]

AudioUnitSetProperty(sound_output[:AudioUnit], render_callback, scope, 0, cb.pointer, cb.size)

AudioOutputUnitStart(sound_output[:AudioUnit])

sleep_time = 1.fdiv(60) # 60th of a second

loop do
  if stopping
    puts "Stopping output"
    AudioOutputUnitStop(sound_output[:AudioUnit])
    AudioUnitUninitialize(sound_output[:AudioUnit])
    AudioComponentInstanceDispose(sound_output[:AudioUnit])
    break
  end
  sleep sleep_time
end
