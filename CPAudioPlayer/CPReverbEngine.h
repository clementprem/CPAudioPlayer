//
//  CPReverbEngine.h
//  
//
//  Created by Clement on 10/31/14.
//  Copyright (c) 2014 Hsenid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface CPReverbEngine : NSObject
-(id)initWithReverbUnit:(AudioUnit)reverbUnit;
-(void)setRoomType:(int)roomType;
@end
