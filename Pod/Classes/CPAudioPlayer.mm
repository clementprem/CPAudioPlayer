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
//Handle uninitilizing
//...

@interface CPAudioPlayer ()

@property (readwrite, nonatomic) double currentPlaybackTime;
@property (strong, nonatomic, readwrite) NSURL *songUrl;
@property (strong, nonatomic, readwrite) CPBandEqulizer *bandEq;
@property (strong, nonatomic, readwrite) CPBandEqulizer *bassBooster;
@end

@implementation CPAudioPlayer
static CPAudioPlayer *globalPlayer;
CPPlayer globalCPPlayer;
AUNode testNode;

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
    AudioUnit convertrunit = nullptr;
    AudioUnit bassBoostConvertrunit = nullptr;
    AudioUnit trebleConvertrunit = nullptr;
    AUNode filePlayerNode = createAndAddNodeToGraphWithType(kAudioUnitType_Generator, kAudioUnitSubType_AudioFilePlayer);
    AUNode mixerNode= createAndAddNodeToGraphWithType(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);
    AUNode outputNode = createAndAddNodeToGraphWithType(kAudioUnitType_Output, kAudioUnitSubType_RemoteIO);
    AUNode eqNode = createAndAddNodeToGraphWithType(kAudioUnitType_Effect, kAudioUnitSubType_AUiPodEQ);
    AUNode bandEQNode = createAndAddNodeToGraphWithType(kAudioUnitType_Effect, kAudioUnitSubType_NBandEQ);
    AUNode bassBoostNode = createAndAddNodeToGraphWithType(kAudioUnitType_Effect, kAudioUnitSubType_LowShelfFilter);
    AUNode trebleNode = createAndAddNodeToGraphWithType(kAudioUnitType_Effect, kAudioUnitSubType_LowShelfFilter);
    AUNode reverbNode = createAndAddNodeToGraphWithType(kAudioUnitType_Effect, kAudioUnitSubType_Reverb2);
    AUNode delayNode = createAndAddNodeToGraphWithType(kAudioUnitType_Effect, kAudioUnitSubType_Delay);
    testNode = createAndAddNodeToGraphWithType(kAudioUnitType_Effect, kAudioUnitSubType_PeakLimiter);
    AUNode converterNode = createAndAddNodeToGraphWithType(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);
    AUNode bassBoostConverterNode = createAndAddNodeToGraphWithType(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);
    AUNode trebleConverterNode = createAndAddNodeToGraphWithType(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);
    //Open graph befor accesing audiounits from the nodes
    CheckError(AUGraphOpen(player->graph), "Failed opening graph");
    //Config the audiounit
    
    configAudioUnitInNode(filePlayerNode, &player->filePlayerUnit);
    configAudioUnitInNode(mixerNode, &player->mxUnit);
    configAudioUnitInNode(bandEQNode, &player->bandEQUnit);
    configAudioUnitInNode(reverbNode, &player->reverbUnit);
    configAudioUnitInNode(delayNode, &player->delayUnit);
    configAudioUnitInNode(testNode, &player->testUnit);
    configAudioUnitInNode(eqNode, &player->eqUnit);
    configAudioUnitInNode(bassBoostNode, &player->bassBoostUnit);
    configAudioUnitInNode(trebleNode, &player->treble);
    configAudioUnitInNode(converterNode, &convertrunit);
    configAudioUnitInNode(bassBoostConverterNode, &bassBoostConvertrunit);
    configAudioUnitInNode(trebleConverterNode, &trebleConvertrunit);
    
    //some AU nodes take a stream format in float by default, while others take it in integers. So fix the issue by adding a converter
    addConverterForNodes(player->eqUnit, player->bandEQUnit, convertrunit);
    addConverterForNodes(player->bandEQUnit, player->bassBoostUnit, bassBoostConvertrunit);
    addConverterForNodes(player->bassBoostUnit, player->treble, trebleConvertrunit);
    //Connect Nodes
    mapNodeToGraph(filePlayerNode, 0, mixerNode, 0);
    mapNodeToGraph(mixerNode, 0, eqNode, 0);
    mapNodeToGraph(eqNode, 0, converterNode, 0);
    mapNodeToGraph(converterNode, 0, bandEQNode, 0);
    mapNodeToGraph(bandEQNode, 0, bassBoostConverterNode, 0);
    mapNodeToGraph(bassBoostConverterNode, 0, bassBoostNode, 0);
    mapNodeToGraph(bassBoostNode, 0, trebleConverterNode, 0);
    mapNodeToGraph(trebleConverterNode, 0, trebleNode, 0);
    mapNodeToGraph(trebleNode, 0, reverbNode, 0);
    mapNodeToGraph(reverbNode, 0, delayNode, 0);
    mapNodeToGraph(delayNode, 0, testNode, 0);
    mapNodeToGraph(testNode, 0, outputNode, 0);
    CheckError(AUGraphInitialize(player->graph), "Faile graph initilization");
}

AUNode createAndAddNodeToGraphWithType(OSType type, OSType subType)
{
    AUNode theNode;
    AudioComponentDescription unitDescription = {0};
    unitDescription.componentType          = type;
    unitDescription.componentSubType       = subType;
    unitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    CheckError(AUGraphAddNode(globalCPPlayer.graph, &unitDescription, &theNode), "Failed add node to graph ");
    return theNode;
}

void addConverterForNodes(AudioUnit fromUnit, AudioUnit toUnit, AudioUnit converterUnit)
{
    //Set conveter unit input format as eq preset unit asbd
    AudioStreamBasicDescription fromAsbd;
    UInt32 streamFormatSize = sizeof(fromAsbd);
    CheckError(AudioUnitGetProperty(fromUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &fromAsbd, &streamFormatSize), "Failed Converter getting output");
    CheckError(AudioUnitSetProperty(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fromAsbd, streamFormatSize), "Failed Converter setting input");
    //Set converter unit out put format as band eq unit asbd
    AudioStreamBasicDescription toAsbd;
    UInt32 bandstreamFormatSize = sizeof(toAsbd);
    CheckError(AudioUnitGetProperty(toUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &toAsbd, &bandstreamFormatSize), "Failed Converter getting input");
    CheckError(AudioUnitSetProperty(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &toAsbd, bandstreamFormatSize), "Failed Converter setting output");
}

void configAudioUnitInNode(AUNode node, AudioUnit *audioUnit)
{
    CheckError(AUGraphNodeInfo(globalCPPlayer.graph, node, NULL, audioUnit), "Failed getting audio unit info from node");
    //have to add maxFPS for all units to play audio in sleep mode.
    if (audioUnit != nullptr) {
        UInt32 maxFPS = 4096;
        CheckError(AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, sizeof(maxFPS)), "Failed setting frame per slice");
    }
}

void mapNodeToGraph(AUNode sourceNode, UInt32 sourceBus, AUNode destNode, UInt32 destBus)
{
    CheckError(AUGraphConnectNodeInput(globalCPPlayer.graph, sourceNode, sourceBus, destNode, destBus), "Failed connecting nodes");
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

//Set up start time for audio -1 imediately start
void setAudioStartTimeStamp(CPPlayer *player) {
    AudioTimeStamp startTime;
    memset(&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    CheckError(AudioUnitSetProperty(player->filePlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)), "Failed setting [kAudioUnitProperty_ScheduleStartTimeStamp]");
}

void addRenderNotifier(CPPlayer *player) {
    CheckError(AudioUnitAddRenderNotify(player->filePlayerUnit, &playRenderNotify, &player), "Failed add render notifier");
}

OSStatus playRenderNotify(void *                      inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *      inTimeStamp,
                          UInt32                      inBusNumber,
                          UInt32                      inNumberFrames,
                          AudioBufferList *           ioData) {
    if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
        float value;
        AudioUnitGetParameter(globalCPPlayer.testUnit, kDynamicsProcessorParam_CompressionAmount, kAudioUnitScope_Global, 0, &value);
        printf("kDynamicsProcessorParam_CompressionAmount  : %f \n", value);
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
    CheckError(AUGraphIsInitialized(globalCPPlayer.graph, &isinitilized), "Failed check in initilized");
    if (!isinitilized) {
        CheckError(AUGraphInitialize(globalCPPlayer.graph), "Failed un reinitilizing graph");
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
    globalCPPlayer.playBackStartFrame = currentFrame;
    CheckError(AudioUnitRemoveRenderNotify(globalCPPlayer.filePlayerUnit, &playRenderNotify, &globalCPPlayer), "Failed remove render notifier");
    CheckError(AudioUnitReset(globalCPPlayer.filePlayerUnit, kAudioUnitScope_Global, 0), "Failed reset file player");
}

void resetAudioFile() {
    if (globalCPPlayer.inputFile != nil) {
        AudioFileClose(globalCPPlayer.inputFile);
        globalCPPlayer.inputFile = nil;
    }
}

void resetGraph() {
    AUGraph graph = globalCPPlayer.graph;
    if (isAUGraphIsRunning(graph)) {
        CheckError(AUGraphStop(graph), "Failed stop AUGraph");
    }
    CheckError(AUGraphUninitialize(graph), "Failed un uninitilizing graph");
}

- (instancetype)init {
    self = [super init];
    if (self) {
        globalCPPlayer = CPPlayer { 0 };
        createAuGraph(&globalCPPlayer);
        NSArray *eqFrequencies = @[@60, @150, @400, @1100, @3100, @8000, @16000];
        _bandEq = [[CPBandEqulizer alloc]initWithBandEQUnitWitFrequency:eqFrequencies audioUnit:globalCPPlayer.bandEQUnit];
        _bassBooster = [[CPBandEqulizer alloc]initWithBandEQUnitWitFrequency:@[@100] audioUnit:globalCPPlayer.bassBoostUnit];
        globalCPPlayer.playBackStartFrame = 0.0;
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
    setUpFile(&globalCPPlayer, inputUrl, isError);
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
    if (globalCPPlayer.inputFile == nil) {
        if (_songUrl != nil) {
            [self setupAudioFileWithURL:_songUrl playBackDuration:_playBackduration isError:&isError];
        }
    }
    if (!isError) {
        initilizeGraph();
        prepareAudioFile(&globalCPPlayer);
        CheckError(AUGraphStart(globalCPPlayer.graph), "Failed start AUGraph");
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
    AudioUnitGetProperty(globalCPPlayer.filePlayerUnit, kAudioUnitProperty_CurrentPlayTime, kAudioUnitScope_Global, 0, &ts, &size);
    resetFilePlayerUnit(ts.mSampleTime + globalCPPlayer.playBackStartFrame);
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
    AudioUnitGetProperty(globalCPPlayer.filePlayerUnit, kAudioUnitProperty_CurrentPlayTime, kAudioUnitScope_Global, 0, &ts, &size);
    double currentTime = (double)(globalCPPlayer.playBackStartFrame + ts.mSampleTime) / globalCPPlayer.asbd.mSampleRate;
    return currentTime;
}

- (void)setPlayBackTime:(double)time {
    if (globalCPPlayer.inputFile == nil) {
        return;
    }
    resetFilePlayerUnit(time * globalCPPlayer.asbd.mSampleRate);
    if (isAUGraphIsRunning(globalCPPlayer.graph)) {
        CheckError(AUGraphStop(globalCPPlayer.graph), "Failed stop AUGraph");
        prepareResumeAudioFile(&globalCPPlayer);
        CheckError(AUGraphStart(globalCPPlayer.graph), "Failed start AUGraph");
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
    CheckError(AudioUnitGetProperty(globalCPPlayer.eqUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &eqPresetArray, &size), "Failed getting [kAudioUnitProperty_FactoryPresets]");
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
    AudioUnitSetProperty(globalCPPlayer.eqUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, preset, sizeof(AUPreset));
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
    AudioUnitGetParameter(globalCPPlayer.delayUnit, kDelayParam_DelayTime, kAudioUnitScope_Global, 0, &value);
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
    CheckError(AudioUnitSetParameter(globalCPPlayer.delayUnit, kDelayParam_WetDryMix, kAudioUnitScope_Global, 0, wetDry, 0),
               "AudioUnitSetProperty[kDelayParam_WetDryMix -- Using Parameter] failed");
    float time =  value*DELAY_TIME;
    CheckError(AudioUnitSetParameter(globalCPPlayer.delayUnit, kDelayParam_DelayTime,
                                     kAudioUnitScope_Global, 0, time, sizeof(UInt32)),
               "AudioUnitSetProperty[kDelayParam_DelayTime] failed");
}

- (float)getChannelBalance {
    float pan;
    AudioUnitGetParameter(globalCPPlayer.mxUnit, kMultiChannelMixerParam_Pan, kAudioUnitScope_Input, 0, &pan);
    return pan;
}

- (void)setChannelBalance:(float)pan {
    AudioUnitSetParameter(globalCPPlayer.mxUnit,
                          kMultiChannelMixerParam_Pan,
                          kAudioUnitScope_Input,
                          0,
                          pan,
                          0);
}

-(float)getBassBoost
{
    float value;
    AudioUnitGetParameter(globalCPPlayer.bassBoostUnit, kAULowShelfParam_Gain, kAudioUnitScope_Global, 0, &value);
    value = (value/12<0)?0:value/12;
    return value;
}

- (void)setbassBoost:(float)value {
    
    AudioUnitSetParameter(globalCPPlayer.bassBoostUnit, kAULowShelfParam_CutoffFrequency, kAudioUnitScope_Global, 0, 120, 0);
    float gain = (value < 0)?0:value*12;
    AudioUnitSetParameter(globalCPPlayer.bassBoostUnit, kAULowShelfParam_Gain, kAudioUnitScope_Global, 0, gain, 0);
}

-(void)setTreble:(float)value
{
    float treble = (value < 0)?0:value*12;
    AudioUnitSetParameter(globalCPPlayer.treble, kHighShelfParam_Gain, kAudioUnitScope_Global, 0, treble, 0);
}

-(float)getTreble
{
    float value;
    AudioUnitGetParameter(globalCPPlayer.treble, kHighShelfParam_Gain, kAudioUnitScope_Global, 0, &value);
    value = (value/12<0)?0:value/12;
    return value;
}

-(void)setReverbType:(int)reverbParam value:(float)value
{
    AudioUnitSetParameter(globalCPPlayer.reverbUnit, reverbParam, kAudioUnitScope_Global, 0, value, 0);
}

-(float)getReverbVauleForType:(int)reverbParam
{
    float value;
    AudioUnitGetParameter(globalCPPlayer.reverbUnit, reverbParam, kAudioUnitScope_Global, 0, &value);
    return value;
}

-(void)setDistrotion:(float)value
{
}

-(void)setDynamicProcess:(float)value parameter:(UInt32)parameterID
{
    NSLog(@"Dynamic ID :%i value:%f", parameterID, value);
    AudioUnitSetParameter(globalCPPlayer.testUnit, parameterID, kAudioUnitScope_Global, 0, value, 0);

}

-(void)removeTestNode
{
    AUGraphRemoveNode(globalCPPlayer.graph, testNode);
}

#pragma mark Utility
- (BOOL)checkFileExistAtUrl:(NSURL *)url {
    NSFileManager *fileMang = [NSFileManager defaultManager];
    return [fileMang fileExistsAtPath:[url path]];
}

@end
