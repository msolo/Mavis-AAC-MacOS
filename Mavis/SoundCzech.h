#ifndef SoundCzech_h
#define SoundCzech_h

#import <AVFoundation/AVFoundation.h>

@interface SoundLevelMonitor : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession* captureSession;
@property (nonatomic, strong) AVCaptureAudioDataOutput* audioOutput;
@property (nonatomic, assign) float peakAudioLevel;
@property (nonatomic, assign) float averageAudioLevel;
@property (nonatomic, assign) float sampleCount;

- (void)startMonitoring;
- (void)stopMonitoring;
- (void)reset;
- (float)averagePeakAudioLevel;
- (float)averageAverageAudioLevel;

@end

void setSystemVolume(float volume);
float getSystemVolume(void);

#endif /* SoundCzech_h */
