//
//  CPBandEqulizer.h
//
//
//  Created by Clement Prem on 9/18/14.
//  Copyright (c) 2014. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface CPBandEqulizer : NSObject
@property (readonly, nonatomic) NSArray *bands;
@property (readonly, nonatomic) UInt32 maxNumberOfBands;
@property (readonly, nonatomic) UInt32 numBands;

-(instancetype)initWithBandEQUnitWitFrequency:(NSArray *)frequency audioUnit:(AudioUnit)bandUnit;
-(AudioUnitParameterValue)gainForBandAtPosition:(NSUInteger)bandPosition;
-(void)setGainForBandAtPosition:(NSInteger)bandPosition value:(float)gain;
@end

NS_ASSUME_NONNULL_END
