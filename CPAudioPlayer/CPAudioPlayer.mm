 //
//  CPAudioPlayer.m
//
//
//  Created by Clement Prem on 8/16/14.
//  Copyright (c) 2014 Clement Prem. All rights reserved.
//

#import "CPAudioPlayer.h"
#import "CPBandEqulizer.h"
#import <AVFoundation/AVFoundation.h>
//:TODO
//Reverb unit
//Handle uninitilizing of stuffs
//Bass, Treble clean up repeating stuffs
//...

@interface CPAudioPlayer ()
@property (readwrite, nonatomic) double currentPlaybackTime;
@property (strong, nonatomic, readwrite) NSURL *songUrl;
@property (strong, nonatomic, readwrite) CPBandEqulizer *bandEq;
@property (strong, nonatomic, readwrite) CPBandEqulizer *bassBooster;
@end

@implementation CPAudioPlayer
static CPAudioPlayer *globalPlayer;
@synthesize myPlayer = myPlayer;


static Boolean CheckError(OSStatus error, const char *operation) {
	if (error == noErr) return false;
	char errorString[20];
	// See if it appears to be a 4-char-code
	*(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
	if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
		errorString[0] = errorString[5] = '\''; errorString[6] = '\0';
	}
	else {
		// No, format it as an integer
		sprintf(errorString, "%d", (int)error);
		fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
	}
	return true;
}

void createAuGraph(CPPlayer *player) {
	CheckError(NewAUGraph(&player->graph), "New graph creation failed");
    
    AUNode filePlayerNode = createNode(player->graph, kAudioUnitType_Generator, kAudioUnitSubType_AudioFilePlayer, &player->filePlayerUnit);
    AUNode mixerNode= createNode(player->graph, kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, &player->mxUnit);
    AUNode outputNode = createNode(player->graph, kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, nullptr);
	AUNode eqNode = createNode(player->graph, kAudioUnitType_Effect, kAudioUnitSubType_AUiPodEQ, &player->eqUnit);
	AUNode bandEQNode = createNode(player->graph, kAudioUnitType_Effect, kAudioUnitSubType_NBandEQ, &player->bandEQUnit);
    AUNode bassBoostNode = createNode(player->graph, kAudioUnitType_Effect, kAudioUnitSubType_LowShelfFilter, &player->bassBoostUnit);
	AUNode trebleNode = createNode(player->graph, kAudioUnitType_Effect, kAudioUnitSubType_LowShelfFilter, &player->treble);
    AUNode reverbNode = createNode(player->graph, kAudioUnitType_Effect, kAudioUnitSubType_Reverb2, &player->reverbUnit);
    AUNode delayNode = createNode(player->graph, kAudioUnitType_Effect, kAudioUnitSubType_Delay, &player->delayUnit);
    AUNode testNode = createNode(player->graph, kAudioUnitType_Effect, kAudioUnitSubType_Distortion, &player->testUnit);

    //Converter Nodes
	AudioUnit convertrunit = nullptr;
    AudioUnit bassBoostConvertrunit = nullptr;
    AudioUnit surroundConvertrunit = nullptr;
    AUNode converterNode = createNode(player->graph, kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter, &convertrunit);
	AUNode bassBoostConverterNode = createNode(player->graph, kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter, &bassBoostConvertrunit);
    AUNode surroundConverterNode = createNode(player->graph, kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter, &surroundConvertrunit);

	CheckError(AUGraphOpen(player->graph), "failed opening graph");
    
    {
	//some AU nodes take a stream format in float by default, while others take it in integers. So fix the issue by adding a converter
    addConverterForNodes(player->eqUnit, player->bandEQUnit, convertrunit);
    //Add converter for bass boost node
    addConverterForNodes(player->bandEQUnit, player->bassBoostUnit, bassBoostConvertrunit);
    //Add converter for surround node
    addConverterForNodes(player->bassBoostUnit, player->treble, surroundConvertrunit);
    }
    
    //Connect Nodes
	{
		CheckError(AUGraphConnectNodeInput(player->graph, filePlayerNode, 0, mixerNode, 0), "Failed Connect nodes (filePlayer - mixer)");
		CheckError(AUGraphConnectNodeInput(player->graph, mixerNode, 0, eqNode, 0), "Failed Connect nodes (filePlayer - mixer)");
		CheckError(AUGraphConnectNodeInput(player->graph, eqNode, 0, converterNode, 0), "Failed Connect nodes (eqNodeeqNode - bassBoostNode)");
		CheckError(AUGraphConnectNodeInput(player->graph, converterNode, 0, bandEQNode, 0), "Failed Connect nodes (bassBoostNode - converterNode)");
		CheckError(AUGraphConnectNodeInput(player->graph, bandEQNode, 0, bassBoostConverterNode, 0), "Failed Connect nodes (filePlayer - mixer)");
		CheckError(AUGraphConnectNodeInput(player->graph, bassBoostConverterNode, 0, bassBoostNode, 0), "Failed Connect nodes (filePlayer - mixer)");
        CheckError(AUGraphConnectNodeInput(player->graph, bassBoostNode, 0, surroundConverterNode, 0), "Failed Connect nodes (mixer - output)");
        CheckError(AUGraphConnectNodeInput(player->graph, surroundConverterNode, 0, trebleNode, 0), "Failed Connect nodes (mixer - output)");
        CheckError(AUGraphConnectNodeInput(player->graph, trebleNode, 0, reverbNode, 0), "Failed Connect nodes (filePlayer - mixer)");
        CheckError(AUGraphConnectNodeInput(player->graph, reverbNode, 0, delayNode, 0), "Failed Connect nodes (filePlayer - mixer)");
        CheckError(AUGraphConnectNodeInput(player->graph, delayNode, 0, testNode, 0), "Failed Connect nodes (filePlayer - mixer)");
		CheckError(AUGraphConnectNodeInput(player->graph, testNode, 0, outputNode, 0), "Failed Connect nodes (filePlayer - mixer)");
	}
	CheckError(AUGraphInitialize(player->graph), "Faile graph initilize");
}

AUNode createNode(AUGraph graph, OSType type, OSType subType, AudioUnit *audioUnit)
{
    AUNode theNode;
        AudioComponentDescription unitDescription;
        unitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
        unitDescription.componentType          = type;
        unitDescription.componentSubType       = subType;
        unitDescription.componentFlags         = 0;
        unitDescription.componentFlagsMask     = 0;
        CheckError(AUGraphAddNode(graph, &unitDescription, &theNode), "Failed add node to graph ");
        CheckError(AUGraphNodeInfo(graph, theNode, NULL, audioUnit), "Failed getting audio unit info from node");
        //have to add maxFPS for all units to play audio in sleep mode.
    if (audioUnit != nullptr) {
        UInt32 maxFPS = 4096;
        AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
    }
 
    return theNode;
}

void addConverterForNodes(AudioUnit fromUnit, AudioUnit toUnit, AudioUnit converterUnit)
{
    //Set conveter unit input format as eq preset unit asbd
    AudioStreamBasicDescription fromAsbd;
    UInt32 streamFormatSize = sizeof(fromAsbd);
    AudioUnitGetProperty(fromUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &fromAsbd, &streamFormatSize);
    AudioUnitSetProperty(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fromAsbd, streamFormatSize);
    
    //Set converter unit out put format as band eq unit asbd
    AudioStreamBasicDescription toAsbd;
    UInt32 bandstreamFormatSize = sizeof(toAsbd);
    AudioUnitGetProperty(toUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &toAsbd, &bandstreamFormatSize);
    AudioUnitSetProperty(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &toAsbd, bandstreamFormatSize);
}

void setUpFile(CPPlayer *player, CFURLRef songUrl, Boolean *isError) {
	AudioFileOpenURL(songUrl, kAudioFileReadPermission, 0, &player->inputFile);
	if (&player->inputFile != nil) {
		UInt32 propSize = sizeof(player->asbd);
		*isError = CheckError(AudioFileGetProperty(player->inputFile, kAudioFilePropertyDataFormat, &propSize, &player->asbd), "Failed geting [kAudioFilePropertyDataFormat]");
	}
	else {
		*isError = true;
	}
}

void prepareAudioFile(CPPlayer *player) {
	//tell the player to load the file
	CheckError(AudioUnitSetProperty(player->filePlayerUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &player->inputFile, sizeof(player->inputFile)), "Failed setting files to load for AU");
	schedulePlayReginForUnit(player);
	setAudioStartTimeStamp(player);
	addRenderNotifier(player);
}

void prepareResumeAudioFile(CPPlayer *player) {
	schedulePlayReginForUnit(player);
	setAudioStartTimeStamp(player);
}

//Schedule audio file region
void schedulePlayReginForUnit(CPPlayer *player) {
	initilizeGraph();
	//Set Prime for unit
	UInt32 defaultVal = 0;
	CheckError(AudioUnitSetProperty(player->filePlayerUnit, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal)), "Failed setting [kAudioUnitProperty_ScheduledFilePrime]");

	//Setup audio file region
	memset(&player->region.mTimeStamp, 0, sizeof(player->region.mTimeStamp));
	player->region.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
	player->region.mTimeStamp.mSampleTime = 0;
	player->region.mCompletionProc = NULL;
	player->region.mCompletionProcUserData = NULL;
	player->region.mAudioFile = player->inputFile;
	player->region.mLoopCount = 0;
	player->region.mStartFrame = player->playBackStartFrame;
	player->region.mFramesToPlay = (UInt32) - 1;
	CheckError(AudioUnitSetProperty(player->filePlayerUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &player->region, sizeof(player->region)), "Failed setting [kAudioUnitProperty_ScheduledFileRegion]");
}

void addRenderNotifier(CPPlayer *player) {
	CheckError(AudioUnitAddRenderNotify(player->filePlayerUnit, &playRenderNotify, &player), "Failed add render notifier");
}

//Set up start time for audio -1 imediately start
void setAudioStartTimeStamp(CPPlayer *player) {
	AudioTimeStamp startTime;
	memset(&startTime, 0, sizeof(startTime));
	startTime.mFlags = kAudioTimeStampSampleTimeValid;
	startTime.mSampleTime = -1;
	CheckError(AudioUnitSetProperty(player->filePlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)), "Failed setting [kAudioUnitProperty_ScheduleStartTimeStamp]");
}

OSStatus playRenderNotify(void *                      inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *      inTimeStamp,
                          UInt32                      inBusNumber,
                          UInt32                      inNumberFrames,
                          AudioBufferList *           ioData) {
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
		double currentPlayTime =  [globalPlayer currentPlaybackTime];
		double totalDuration = globalPlayer.playBackduration;
		if (currentPlayTime >= totalDuration) {
			if (globalPlayer && globalPlayer.songCompletion) {
				globalPlayer.songCompletion();
				resetFilePlayerUnit(0.0);
			}
		}
	}
	return noErr;
}

#pragma mark Utilities
void initilizeGraph() {
	Boolean isinitilized;
	CheckError(AUGraphIsInitialized(globalPlayer.myPlayer.graph, &isinitilized), "Failed check in initilized");
	if (!isinitilized) {
		CheckError(AUGraphInitialize(globalPlayer.myPlayer.graph), "Failed un reinitilizing graph");
	}
}

Boolean isAUGraphIsRunning(AUGraph graph) {
	Boolean isRunning = NO;
	if (graph != nil) {
		CheckError(AUGraphIsRunning(graph, &isRunning), "Failed checking is Augraph is running");
	}
	return isRunning;
}

void closeGraph(CPPlayer *player) {
	reset(0.0);
	CheckError(AUGraphClose(player->graph), "Failed closing audio graph");
}

//Reset file player unit & audio file, to clear some memory
void reset(Float64 currentFrame) {
	resetFilePlayerUnit(currentFrame);
	resetAudioFile();
	resetGraph();
}

void resetFilePlayerUnit(Float64 currentFrame) {
	globalPlayer->myPlayer.playBackStartFrame = currentFrame;
	CheckError(AudioUnitRemoveRenderNotify(globalPlayer->myPlayer.filePlayerUnit, &playRenderNotify, &globalPlayer->myPlayer), "Failed remove render notifier");
	CheckError(AudioUnitReset(globalPlayer->myPlayer.filePlayerUnit, kAudioUnitScope_Global, 0), "Failed reset file player");
}

void resetAudioFile() {
	if (globalPlayer.myPlayer.inputFile != nil) {
		AudioFileClose(globalPlayer.myPlayer.inputFile);
		globalPlayer->myPlayer.inputFile = nil;
	}
}

void resetGraph() {
	AUGraph graph = globalPlayer.myPlayer.graph;
	if (isAUGraphIsRunning(graph)) {
		CheckError(AUGraphStop(graph), "Failed stop AUGraph");
	}
	CheckError(AUGraphUninitialize(graph), "Failed un uninitilizing graph");
}

- (instancetype)init {
	self = [super init];
	if (self) {
		myPlayer = CPPlayer { 0 };
		createAuGraph(&myPlayer);
		NSArray *eqFrequencies = @[@60, @150, @400, @1100, @3100, @8000, @16000];
		_bandEq = [[CPBandEqulizer alloc]initWithBandEQUnitWitFrequency:eqFrequencies audioUnit:myPlayer.bandEQUnit];
		_bassBooster = [[CPBandEqulizer alloc]initWithBandEQUnitWitFrequency:@[@100] audioUnit:myPlayer.bassBoostUnit];
		myPlayer.playBackStartFrame = 0.0;
		globalPlayer = self;
        [self setDefaultValueForUnits];
		return self;
	}
	return nil;
}

- (void)setupAudioFileWithURL:(NSURL *)audioUrl playBackDuration:(double)playBackDuration isError:(Boolean *)isError {
	_playBackduration = playBackDuration;
	_songUrl = audioUrl;
	reset(0.0);
	CFURLRef inputUrl = (__bridge CFURLRef)audioUrl;
	setUpFile(&myPlayer, inputUrl, isError);
}

- (void)handleSongPlayingCompletion:(_songPlayCompletionHandler)handler {
	if (_songCompletion) {
		_songCompletion = nil;
	}
	_songCompletion = handler;
}

#pragma mark Audio Control
- (BOOL)play {
	Boolean isError = false;
	//Check if input file is there, else create inputfileid.
	if (myPlayer.inputFile == nil) {
		if (_songUrl != nil) {
			[self setupAudioFileWithURL:_songUrl playBackDuration:_playBackduration isError:&isError];
		}
	}
	if (!isError) {
		initilizeGraph();
		prepareAudioFile(&myPlayer);
		CheckError(AUGraphStart(myPlayer.graph), "Failed start AUGraph");
	}
	else {
		NSLog(@"Error %s", __FUNCTION__);
	}
	Boolean isPlaySuccess = !isError;
	return isPlaySuccess;
}

- (void)pause {
	//Store the current frame so you can resume nicely
	AudioTimeStamp ts;
	UInt32 size = sizeof(ts);
	AudioUnitGetProperty(myPlayer.filePlayerUnit, kAudioUnitProperty_CurrentPlayTime, kAudioUnitScope_Global, 0, &ts, &size);
	resetFilePlayerUnit(ts.mSampleTime + myPlayer.playBackStartFrame);
	resetGraph();
}

- (void)stop {
	reset(0.0);
}

#pragma mark Playback time
- (double)currentPlaybackTime {
	//Get the current playback time by calculation playbackStartFrame + sampleTime. Playback start time changes when moving seekbar.
	AudioTimeStamp ts;
	UInt32 size = sizeof(ts);
	AudioUnitGetProperty(myPlayer.filePlayerUnit, kAudioUnitProperty_CurrentPlayTime, kAudioUnitScope_Global, 0, &ts, &size);
	double currentTime = (double)(myPlayer.playBackStartFrame + ts.mSampleTime) / myPlayer.asbd.mSampleRate;
	return currentTime;
}

- (void)setPlayBackTime:(double)time {
	if (myPlayer.inputFile == nil) {
		return;
	}
	resetFilePlayerUnit(time * myPlayer.asbd.mSampleRate);
	if (isAUGraphIsRunning(myPlayer.graph)) {
		CheckError(AUGraphStop(myPlayer.graph), "Failed stop AUGraph");
		prepareResumeAudioFile(&myPlayer);
		CheckError(AUGraphStart(myPlayer.graph), "Failed start AUGraph");
	}
}

#pragma mark AUDIO PRocessing
-(void)setDefaultValueForUnits
{
    [self setRoomSize:0.0];
}

#pragma mark iPod Eq presets
- (CFArrayRef)getEqulizerPresets {
	UInt32 size = sizeof(eqPresetArray);
	CheckError(AudioUnitGetProperty(myPlayer.eqUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &eqPresetArray, &size), "Failed getting [kAudioUnitProperty_FactoryPresets]");
	return eqPresetArray;
}

- (void)setiPodEQPreset:(UInt32)index {
	if (!eqPresetArray) {
		[self getEqulizerPresets];
	}
	AUPreset *preset = (AUPreset *)CFArrayGetValueAtIndex(eqPresetArray, index);
	[self setiPodEQPresetWithPreset:preset];
}

- (void)setiPodEQPresetWithPreset:(AUPreset *)preset {
	AudioUnitSetProperty(myPlayer.eqUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, preset, sizeof(AUPreset));
}

#pragma mark Band Equlizer
- (void)setBandValue:(NSArray *)value {
	for (int bandPosition = 0; bandPosition < value.count; bandPosition++) {
		float bandValue = [value[bandPosition] floatValue];
		[_bandEq setGainForBandAtPosition:bandPosition value:bandValue];
	}
}

- (float)getValueForBand:(NSInteger)bandPosition {
	return [_bandEq gainForBandAtPosition:bandPosition];
}

- (NSArray *)getAllBands {
	return _bandEq.bands;
}

#define DELAY_WETDRYMIX 5.0
#define DELAY_TIME 0.2
- (float)getRommSize {
    float value;
    AudioUnitGetParameter(myPlayer.delayUnit, kDelayParam_DelayTime, kAudioUnitScope_Global, 0, &value);
    value =  value/DELAY_TIME;
    return value;
}

- (void)setRoomSize:(float)value {
    
    if ([self getRommSize] == value) {
        return;
    }
    float wetDry = value * DELAY_WETDRYMIX;
    if (wetDry>DELAY_WETDRYMIX) {
        wetDry = DELAY_WETDRYMIX;
    }
    CheckError(AudioUnitSetParameter(myPlayer.delayUnit, kDelayParam_WetDryMix, kAudioUnitScope_Global, 0, wetDry, 0),
               "AudioUnitSetProperty[kDelayParam_WetDryMix -- Using Parameter] failed");
    float time =  value*DELAY_TIME;
	CheckError(AudioUnitSetParameter(myPlayer.delayUnit, kDelayParam_DelayTime,
	                                kAudioUnitScope_Global, 0, time, sizeof(UInt32)),
	           "AudioUnitSetProperty[kDelayParam_DelayTime] failed");
}

- (float)getChannelBalance {
	float pan;
	AudioUnitGetParameter(myPlayer.mxUnit, kMultiChannelMixerParam_Pan, kAudioUnitScope_Input, 0, &pan);
	return pan;
}

- (void)setChannelBalance:(float)pan {
	AudioUnitSetParameter(myPlayer.mxUnit,
	                      kMultiChannelMixerParam_Pan,
	                      kAudioUnitScope_Input,
	                      0,
	                      pan,
	                      0);
}

-(float)getBassBoost
{
    float value;
    AudioUnitGetParameter(myPlayer.bassBoostUnit, kAULowShelfParam_Gain, kAudioUnitScope_Global, 0, &value);
    value = (value/12<0)?0:value/12;
    return value;
}

- (void)setbassBoost:(float)value {
    
    AudioUnitSetParameter(myPlayer.bassBoostUnit, kAULowShelfParam_CutoffFrequency, kAudioUnitScope_Global, 0, 120, 0);
    float gain = (value < 0)?0:value*12;
    AudioUnitSetParameter(myPlayer.bassBoostUnit, kAULowShelfParam_Gain, kAudioUnitScope_Global, 0, gain, 0);
}

-(void)setTreble:(float)value
{
    float treble = (value < 0)?0:value*12;
    AudioUnitSetParameter(myPlayer.treble, kHighShelfParam_Gain, kAudioUnitScope_Global, 0, treble, 0);
}

-(float)getTreble
{
    float value;
    AudioUnitGetParameter(myPlayer.treble, kHighShelfParam_Gain, kAudioUnitScope_Global, 0, &value);
    value = (value/12<0)?0:value/12;
    return value;
}

-(void)setReverbType:(int)reverbParam value:(float)value
{
    AudioUnitSetParameter(myPlayer.reverbUnit, reverbParam, kAudioUnitScope_Global, 0, value, 0);
}

-(float)getReverbVauleForType:(int)reverbParam
{
    float value;
    AudioUnitGetParameter(myPlayer.reverbUnit, reverbParam, kAudioUnitScope_Global, 0, &value);
    return value;
}

#pragma mark Utility
- (BOOL)checkFileExistAtUrl:(NSURL *)url {
	NSFileManager *fileMang = [NSFileManager defaultManager];
	return [fileMang fileExistsAtPath:[url path]];
}

@end
