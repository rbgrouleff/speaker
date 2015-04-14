#include <stdint.h>
#include <AudioUnit/AudioUnit.h>

#ifndef _FOO_GUARD
#define _FOO_GUARD

typedef int16_t int16;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

typedef void (*FillBuffer)(AudioBufferList *audioBufferList, UInt32 frames, double renderPhase, double phaseStep);

typedef struct sound_output
{
  Float64 SamplesPerSecond;
  AudioUnit AudioUnit;

  Float64 Frequency;
  double RenderPhase;

  FillBuffer FillBufferProc;
} sound_output;

OSStatus SineWaveRenderCallback(void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData);

void InitCoreAudio(sound_output *SoundOutput);

void StartCoreAudio(sound_output *SoundOutput);

void StopCoreAudio(sound_output *SoundOutput);
#endif
