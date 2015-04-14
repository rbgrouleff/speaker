#include <stdio.h>
#include <signal.h>

#include "foo.h"

OSStatus SineWaveRenderCallback(void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData)
{
#pragma unused(ioActionFlags)
#pragma unused(inTimeStamp)
#pragma unused(inBusNumber)

  sound_output *SoundOutput = ((sound_output *)inRefCon);

  Float32 *outputBuffer = (Float32 *)ioData->mBuffers[0].mData;
  const double phaseStep = (SoundOutput->Frequency / SoundOutput->SamplesPerSecond) * (2.0 * M_PI);

  SoundOutput->FillBufferProc(ioData, inNumberFrames, SoundOutput->RenderPhase, phaseStep);
  SoundOutput->RenderPhase += phaseStep * inNumberFrames;

  //for (UInt32 i = 0; i < inNumberFrames; i++)
  //{
  //  Float32 val = 0.7 * sin(SoundOutput->RenderPhase);
  //  outputBuffer[i] = val;
  //  SoundOutput->RenderPhase += phaseStep;
  //}

  for (UInt32 i = 1; i < ioData->mNumberBuffers; i++)
  {
    memcpy(ioData->mBuffers[i].mData, outputBuffer, ioData->mBuffers[i].mDataByteSize);
  }

  return noErr;
}

void InitCoreAudio(sound_output *SoundOutput)
{
  //AudioComponentDescription acd;
  //acd.componentType = kAudioUnitType_Output;
  //acd.componentSubType = kAudioUnitSubType_DefaultOutput;
  //acd.componentManufacturer = kAudioUnitManufacturer_Apple;

  //AudioComponent outputComponent = AudioComponentFindNext(NULL, acd);

  //AudioUnit *auPtr = &SoundOutput->AudioUnit;
  //AudioComponentInstanceNew(outputComponent, auPtr);
  //AudioUnitInitialize(SoundOutput->AudioUnit);

  //AudioStreamBasicDescription asbd;
  //asbd.mSampleRate = SoundOutput->SamplesPerSecond;
  //asbd.mFormatID = kAudioFormatLinearPCM;
  //asbd.mFormatFlags = kLinearPCMFormatFlagIsFloat;
  //asbd.mChannelsPerFrame = 1;
  //asbd.mFramesPerPacket = 1;
  //asbd.mBitsPerChannel = 1 * sizeof(Float32) * 8;
  //asbd.mBytesPerPacket = 1 * sizeof(Float32);
  //asbd.mBytesPerFrame = 1 * sizeof(Float32);

  //AudioUnitSetProperty(SoundOutput->AudioUnit,
  //    kAudioUnitProperty_StreamFormat,
  //    kAudioUnitScope_Input,
  //    0,
  //    &asbd,
  //    sizeof(asbd));

  AURenderCallbackStruct cb;
  cb.inputProc = SineWaveRenderCallback;
  cb.inputProcRefCon = SoundOutput;

  AudioUnitSetProperty(SoundOutput->AudioUnit,
      kAudioUnitProperty_SetRenderCallback,
      kAudioUnitScope_Global,
      0,
      &cb,
      sizeof(cb));
};

void StartCoreAudio(sound_output *SoundOutput)
{
  AudioOutputUnitStart(SoundOutput->AudioUnit);
}

void StopCoreAudio(sound_output *SoundOutput)
{
  printf("Stopping\n");
  AudioOutputUnitStop(SoundOutput->AudioUnit);
  AudioUnitUninitialize(SoundOutput->AudioUnit);
  AudioComponentInstanceDispose(SoundOutput->AudioUnit);
}
