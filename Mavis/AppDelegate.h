#import "CompletionManager.h"
#import "MSTextView.h"
#import "SoundCzech.h"
#import <AVFoundation/AVFoundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSControlTextEditingDelegate, NSTableViewDataSource,
                                   NSTextFieldDelegate, NSAlertDelegate> {
    SoundLevelMonitor* noiseMonitor;

    IBOutlet NSWindow* window;
    IBOutlet NSWindow* prefsWindow;
    IBOutlet NSWindow* sharePlayWindow;
    IBOutlet NSWindow* scriptWindow;
    IBOutlet NSWindow* completionWindow;

    IBOutlet MSTextView* sayTextView;
    IBOutlet MSTextView* scriptTextView;

    IBOutlet NSTableView* historyTableView;

    IBOutlet NSArrayController* voiceArrayController;
    IBOutlet NSArrayController* historyArrayController;

    IBOutlet NSTextField* noiseDisplay;

    IBOutlet NSMenu* speakContextMenu;
    IBOutlet CompletionManager* completionManager;

    BOOL triggeredAutocompleteAutomatically;
}
@property (readonly, strong) NSPersistentContainer* persistentContainer;
@property (nonatomic, strong) NSTimer* noiseTimer;
@property NSArray<AVSpeechSynthesisVoice*>* voices;
@property (nonatomic, setter=setVoice:) AVSpeechSynthesisVoice* voice;
@property NSMutableArray<NSString*>* history;

- (CompletionManager*)completionManager;

@end
