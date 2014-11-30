//
//  CPReverbEngine.m
//  
//
//  Created by Clement on 10/31/14.
//  Copyright (c) 2014 Hsenid. All rights reserved.
//

#import "CPReverbEngine.h"

@interface CPReverbEngine ()
{
    AudioUnit _reverbUnit;
}
@end
@implementation CPReverbEngine

static Boolean CheckError(OSStatus error, const char *operation) {
    if (error == noErr) return false;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4]))
    { errorString[0] = errorString[5] = '\''; errorString[6] = '\0';
    }
    else{
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
        fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    }
    return true;
}

-(id)initWithReverbUnit:(AudioUnit)reverbUnit
{
    self = [super init];
    if (self) {
        _reverbUnit = reverbUnit;
        
    }
    return self;
}

-(void)setRoomType:(int)roomType
{
    NSLog(@"Room size *** %i", roomType);
    //kReverbRoomType_LargeHall2
    UInt32 type = kReverbRoomType_LargeHall2;

    CheckError(AudioUnitSetProperty(_reverbUnit, kAudioUnitProperty_ReverbRoomType,
                                    kAudioUnitScope_Global, 0, &type, sizeof(UInt32)),
               "AudioUnitSetProperty[kAudioUnitProperty_ReverbRoomType] failed");
}

@end
