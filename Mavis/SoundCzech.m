#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>

#import "SoundCzech.h"

float getSystemVolume(void) {
    Float32 volume;
    UInt32 size = sizeof(volume);

    // Default output device (typically speakers or headphones)
    AudioDeviceID deviceID = 0;
    AudioObjectPropertyAddress address = {kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal,
                                          kAudioObjectPropertyElementMaster};

    // Get the default output device
    OSStatus err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, &deviceID);
    if (err != noErr) {
        NSLog(@"unable to get default audio device: %d", err);
        return -1.0f;
    }

    // Get the volume property for output device
    address.mSelector = kAudioDevicePropertyVolumeScalar;
    address.mScope = kAudioDevicePropertyScopeOutput;

    err = AudioObjectGetPropertyData(deviceID, &address, 0, NULL, &size, &volume);
    if (err != noErr) {
        NSLog(@"unable to get default audio volume: %d", err);
        return -1.0f;
    }

    return volume;
}

void setSystemVolume(float volume) {
    UInt32 size = sizeof(volume);

    // Default output device (typically speakers or headphones)
    AudioDeviceID deviceID = 0;
    AudioObjectPropertyAddress address = {kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal,
                                          kAudioObjectPropertyElementMaster};

    // Get the default output device
    OSStatus err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, &deviceID);
    if (err != noErr) {
        NSLog(@"unable to get default audio device: %d", err);
        return;
    }

    // Set the volume property for output device
    address.mSelector = kAudioDevicePropertyVolumeScalar;
    address.mScope = kAudioDevicePropertyScopeOutput;

    err = AudioObjectSetPropertyData(deviceID, &address, 0, NULL, size, &volume);
    if (err != noErr) {
        NSLog(@"unable to set default audio device: %d", err);
        return;
    }
}

@implementation SoundLevelMonitor

- (void)startMonitoring {
    // Set up capture session
    self.captureSession = [[AVCaptureSession alloc] init];

    // Set up the audio input
    AVCaptureDevice* audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError* error = nil;
    AVCaptureDeviceInput* audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];

    if (error) {
        NSLog(@"Error setting up audio input: %@", error.localizedDescription);
        return;
    }

    if ([self.captureSession canAddInput:audioInput]) {
        [self.captureSession addInput:audioInput];
    }

    // Set up the audio output
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t queue = dispatch_queue_create("AudioQueue", NULL);
    [self.audioOutput setSampleBufferDelegate:self queue:queue];

    if ([self.captureSession canAddOutput:self.audioOutput]) {
        [self.captureSession addOutput:self.audioOutput];
    }

    // Start the capture session
    [self.captureSession startRunning];
}

- (void)stopMonitoring {
    [self.captureSession stopRunning];
}

// Average of peak samples between resets.
- (float)averagePeakAudioLevel {
    return self.peakAudioLevel / self.sampleCount;
}

- (float)averageAverageAudioLevel {
    return self.averageAudioLevel / self.sampleCount;
}

- (void)reset {
    self.peakAudioLevel = 0.0;
    self.averageAudioLevel = 0.0;
    self.sampleCount = 0;
}

#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput*)output
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection*)connection {
    // There is only one channel for the built-in microphone.
    AVCaptureAudioChannel* chan = connection.audioChannels[0];
    self.peakAudioLevel += chan.peakHoldLevel;
    self.averageAudioLevel += chan.averagePowerLevel;
    self.sampleCount++;
}

@end
