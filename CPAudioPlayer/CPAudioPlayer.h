//
//  CPAudioPlayer.h
//  
//
//  Created by Clement Prem on 8/16/14.
//  Copyright (c) 2014 Clement Prem. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef struct {
    AUGraph graph;
    AudioFileID inputFile;
    AudioStreamBasicDescription asbd;
    AudioUnit bandEQUnit;
    AudioUnit mxUnit;
    AudioUnit eqUnit;
    AudioUnit delayUnit;
    AudioUnit bassBoostUnit;
    AudioUnit treble;
    AudioUnit filePlayerUnit;
    AudioUnit reverbUnit;
    AudioUnit testUnit;
    Float64 playBackStartFrame; //The frame the player should start playing, when pauesed & resume
    ScheduledAudioFileRegion region;
}CPPlayer;

typedef enum {
    LEFT = 0,
    RIGHT = 1
}CHANNEL;

typedef void (^_songPlayCompletionHandler)();
@interface CPAudioPlayer : NSObject
{
    @private CFArrayRef eqPresetArray;
}

@property (nonatomic)CPPlayer myPlayer;
@property (nonatomic)double playBackduration;
@property (nonatomic, strong, readonly)NSURL *songUrl;
@property (readonly, nonatomic)double currentPlaybackTime;
@property (nonatomic, copy)_songPlayCompletionHandler songCompletion;

/**
 Audio Controll & cycle methods
 */
-(BOOL)play;
-(void)pause;
-(void)stop;
-(void)setupAudioFileWithURL:(NSURL *)audioUrl playBackDuration:(double)playBackDuration isError:(Boolean *)isError;
-(void)handleSongPlayingCompletion:(_songPlayCompletionHandler)handler;
-(void)setPlayBackTime:(double)time;
/**
 Audio manipulation methods
 */
#pragma mark iPod Eq presets
-(CFArrayRef)getEqulizerPresets;
-(void)setiPodEQPreset:(UInt32)index;

#pragma mark Band Equlizer
-(void)setBandValue:(NSArray *)value;
-(float)getValueForBand:(NSInteger)bandPosition;
-(NSArray *)getAllBands;

#pragma Room Size
-(void)setRoomSize:(float)value;
-(float)getRommSize;

/**
 pan -1 -> 1 :0
 */
-(void)setChannelBalance:(float)pan;
-(float)getChannelBalance;

//Bass boost
-(void)setbassBoost:(float)value;
-(float)getBassBoost;

//Treble boost
-(void)setTreble:(float)value;
-(float)getTreble;

//Reverb
-(void)setReverbType:(int)reverbParam value:(float)value;
-(float)getReverbVauleForType:(int)reverbParam;
@end
