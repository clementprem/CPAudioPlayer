//
//  CPBandEqulizer.m
//  
//
//  Created by Clement Prem on 9/18/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "CPBandEqulizer.h"

@interface CPBandEqulizer ()
{
    AudioUnit bandEQunit;
}
@property (readwrite, nonatomic) UInt32 maxNumberOfBands;
@property (readwrite, nonatomic) UInt32 numBands; // Can only be set if the equalizer unit is uninitialized.
@property (readwrite, nonatomic) NSArray *bands;
@end

@implementation CPBandEqulizer

-(id)initWithBandEQUnitWitFrequency:(NSArray *)frequency audioUnit:(AudioUnit)bandUnit;
{
    self = [super init];
    if (self) {
        bandEQunit = bandUnit;
        self.numBands = (UInt32)frequency.count;
        self.bands = frequency;
    }
    return self;
}

# pragma mark - EQ wrapper methods

- (UInt32)maxNumberOfBands
{
    UInt32 maxNumBands = 0;
    UInt32 propSize = sizeof(maxNumBands);
    AudioUnitGetProperty(bandEQunit,
                        kAUNBandEQProperty_MaxNumberOfBands,
                        kAudioUnitScope_Global,
                        0,
                        &maxNumBands,
                        &propSize);
    
    return maxNumBands;
}


- (UInt32)numBands
{
    UInt32 numBands;
    UInt32 propSize = sizeof(numBands);
    AudioUnitGetProperty(bandEQunit,
                         kAUNBandEQProperty_NumberOfBands,
                         kAudioUnitScope_Global,
                         0,
                         &numBands,
                         &propSize);
    
    return numBands;
}

- (void)setNumBands:(UInt32)numBands
{
    AudioUnitSetProperty(bandEQunit,
                         kAUNBandEQProperty_NumberOfBands,
                         kAudioUnitScope_Global,
                         0,
                         &numBands,
                         sizeof(numBands));
}


-(void)setBands:(NSArray *)bands
{
    _bands = bands;
    [self setMaxNumberOfBands:(UInt32)_bands.count];
    for (UInt32 i=0; i<bands.count; i++) {
        AudioUnitSetParameter(bandEQunit,
                              kAUNBandEQParam_Frequency+i,
                              kAudioUnitScope_Global,
                              0,
                              (AudioUnitParameterValue)[[bands objectAtIndex:i] floatValue],
                              0);
          // Set the bypass
        AudioUnitSetParameter(bandEQunit,
                              kAUNBandEQParam_BypassBand+i,
                              kAudioUnitScope_Global,
                              0,
                              0,
                              0);
        //Set bandwith

        AudioUnitSetParameter(bandEQunit,
                              kAUNBandEQParam_Bandwidth+i,
                              kAudioUnitScope_Global,
                              0,
                              1.5,
                              0);
           }
}


- (AudioUnitParameterValue)gainForBandAtPosition:(NSUInteger)bandPosition
{
    AudioUnitParameterValue gain;
    AudioUnitParameterID parameterID = kAUNBandEQParam_Gain + (UInt32)bandPosition;
    
    AudioUnitGetParameter(bandEQunit,
                          parameterID,
                          kAudioUnitScope_Global,
                          0,
                          &gain);
    return gain;
}

-(void)setGainForBandAtPosition:(NSInteger)bandPosition value:(float)gain
{
    AudioUnitParameterID parameterID = (UInt32) kAUNBandEQParam_Gain + (UInt32)bandPosition;
    AudioUnitSetParameter(bandEQunit,
                          parameterID,
                          kAudioUnitScope_Global,
                          0,
                          gain,
                          0);
}
@end
