#import "AudioManager.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioManager {
    AVAudioEngine* audioEngine;
    NSMutableDictionary<NSString*, AVAudioPCMBuffer*>* bufferCache;
}

+ (AudioManager*)sharedInstance {
    static AudioManager* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (AudioManager*)init {
    self = [super init];
    audioEngine = [[AVAudioEngine alloc] init];
    bufferCache = [[NSMutableDictionary alloc] initWithCapacity:128];
    return self;
}

- (void)playAudioFromFile:(NSURL*)fileURL volume:(float)volume {
    AVAudioPCMBuffer* audioBuffer = bufferCache[fileURL.absoluteString];
    NSError* error = nil;

    if (audioBuffer == nil) {
        // Load the audio file into an AVAudioFile
        AVAudioFile* audioFile = [[AVAudioFile alloc] initForReading:fileURL error:&error];
        if (error) {
            NSLog(@"Error loading audio file: %@", error.localizedDescription);
            return;
        }

        // Read the audio data into an AVAudioPCMBuffer
        AVAudioFormat* fileFormat = [audioFile processingFormat];
        audioBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:fileFormat
                                                    frameCapacity:(AVAudioFrameCount)audioFile.length];
        [audioFile readIntoBuffer:audioBuffer error:&error];
        if (error) {
            NSLog(@"Error reading audio buffer: %@", error.localizedDescription);
            return;
        }
        bufferCache[fileURL.absoluteString] = audioBuffer;
    }

    // Create an AVAudioEngine instance
    AVAudioPlayerNode* playerNode = [[AVAudioPlayerNode alloc] init];
    // Attach the player node to the audio engine
    [audioEngine attachNode:playerNode];

    // Create and attach an AVAudioMixerNode (default output device)
    // make sure to use the fileFormat to configure the output channels correctly.
    [audioEngine connect:playerNode to:audioEngine.mainMixerNode format:audioBuffer.format];

    // Start the audio engine
    [audioEngine startAndReturnError:&error];
    if (error) {
        NSLog(@"Error starting audio engine: %@", error.localizedDescription);
        return;
    }

    [playerNode setVolume:volume];

    // Schedule the buffer for playback
    [playerNode scheduleBuffer:audioBuffer completionHandler:nil];

    // Play the audio
    [playerNode play];
}

@end
