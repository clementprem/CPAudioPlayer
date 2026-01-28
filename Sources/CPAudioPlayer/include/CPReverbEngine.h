//
//  CPReverbEngine.h
//
//
//  Created by Clement on 10/31/14.
//  Copyright (c) 2014. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface CPReverbEngine : NSObject
-(instancetype)initWithReverbUnit:(AudioUnit)reverbUnit;
-(void)setRoomType:(int)roomType;
@end

NS_ASSUME_NONNULL_END
