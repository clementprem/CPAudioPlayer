//
//  CPUtils.c
//  FlipBeats
//
//  Created by Clement on 10/31/14.
//  Copyright (c) 2014 Hsenid. All rights reserved.
//

#include "CPUtils.h"

/*
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
    AUNode outputNode;
    {
        AudioComponentDescription outptdesc = { 0 };
        outptdesc.componentType = kAudioUnitType_Output;
        outptdesc.componentSubType = kAudioUnitSubType_RemoteIO;
        outptdesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        CheckError(AUGraphAddNode(player->graph, &outptdesc, &outputNode), "Fail adding output node with component description");
    }
    AUNode mixerNode;
    {
        AudioComponentDescription mixerDesc = { 0 };
        mixerDesc.componentType = kAudioUnitType_Mixer;
        mixerDesc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
        mixerDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        CheckError(AUGraphAddNode(player->graph, &mixerDesc, &mixerNode), "Failed adding mixer node");
    }
    AUNode eqNode;
    {
        //iPod eq node
        AudioComponentDescription effectComponent = { 0 };
        effectComponent.componentType = kAudioUnitType_Effect;
        effectComponent.componentSubType = kAudioUnitSubType_AUiPodEQ;
        effectComponent.componentManufacturer = kAudioUnitManufacturer_Apple;
        CheckError(AUGraphAddNode(player->graph, &effectComponent, &eqNode), "failed Effect adding node");
    }
    AUNode bandEQNode;
    {
        AudioComponentDescription bandEqComponent = { 0 };
        bandEqComponent.componentType = kAudioUnitType_Effect;
        bandEqComponent.componentSubType = kAudioUnitSubType_NBandEQ;
        bandEqComponent.componentManufacturer = kAudioUnitManufacturer_Apple;
        bandEqComponent.componentFlags = 0;
        bandEqComponent.componentFlagsMask = 0;
        CheckError(AUGraphAddNode(player->graph, &bandEqComponent, &bandEQNode), "Failed band EQ node");
    }
    AUNode bassBoostNode;
    {
        AudioComponentDescription bassBoostComponent = { 0 };
        bassBoostComponent.componentType = kAudioUnitType_Effect;
        bassBoostComponent.componentSubType = kAudioUnitSubType_NBandEQ;
        bassBoostComponent.componentManufacturer = kAudioUnitManufacturer_Apple;
        bassBoostComponent.componentFlags = 0;
        bassBoostComponent.componentFlagsMask = 0;
        CheckError(AUGraphAddNode(player->graph, &bassBoostComponent, &bassBoostNode), "Failed bass boost node");
    }
    
    
    AUNode reverbNode;
    {
        AudioComponentDescription reverbComponent = { 0 };
        reverbComponent.componentType = kAudioUnitType_Effect;
        reverbComponent.componentSubType = kAudioUnitSubType_Reverb2;
        reverbComponent.componentManufacturer = kAudioUnitManufacturer_Apple;
        reverbComponent.componentFlags = 0;
        reverbComponent.componentFlagsMask = 0;
        CheckError(AUGraphAddNode(player->graph, &reverbComponent, &reverbNode), "Failed  reverb node");
    }
    
    AUNode filePlayerNode;
    {
        AudioComponentDescription filePlayDesc = { 0 };
        filePlayDesc.componentType = kAudioUnitType_Generator;
        filePlayDesc.componentSubType = kAudioUnitSubType_AudioFilePlayer;
        filePlayDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        CheckError(AUGraphAddNode(player->graph, &filePlayDesc, &filePlayerNode), "Failed file player node creation");
    }
    AUNode converterNode;
    AudioUnit convertrunit = 0;
    {
        AudioComponentDescription convertUnitDescription;
        convertUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
        convertUnitDescription.componentType          = kAudioUnitType_FormatConverter;
        convertUnitDescription.componentSubType       = kAudioUnitSubType_AUConverter;
        convertUnitDescription.componentFlags         = 0;
        convertUnitDescription.componentFlagsMask     = 0;
        AUGraphAddNode(player->graph, &convertUnitDescription, &converterNode);
    }
    
    AUNode bassBoostConverterNode;
    AudioUnit bassBoostConvertrunit = 0;
    {
        AudioComponentDescription bassBoostConvertUnitDescription;
        bassBoostConvertUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
        bassBoostConvertUnitDescription.componentType          = kAudioUnitType_FormatConverter;
        bassBoostConvertUnitDescription.componentSubType       = kAudioUnitSubType_AUConverter;
        bassBoostConvertUnitDescription.componentFlags         = 0;
        bassBoostConvertUnitDescription.componentFlagsMask     = 0;
        AUGraphAddNode(player->graph, &bassBoostConvertUnitDescription, &bassBoostConverterNode);
    }
    
    CheckError(AUGraphOpen(player->graph), "failed opening graph");
    {
        //Get audio unit from node and store in struct so it can be used later :O
        CheckError(AUGraphNodeInfo(player->graph, filePlayerNode, NULL, &player->filePlayerUnit), "Failed getting file player Audio unit from node");
        CheckError(AUGraphNodeInfo(player->graph, eqNode, NULL, &player->eqUnit), "Failed getting EQ Audio unit from node");
        CheckError(AUGraphNodeInfo(player->graph, mixerNode, NULL, &player->mxUnit), "Failed getting Mixer Audio unit from node");
        CheckError(AUGraphNodeInfo(player->graph, bandEQNode, NULL, &player->bandEQUnit), "Failed getting band eq info");
        CheckError(AUGraphNodeInfo(player->graph, converterNode, NULL, &convertrunit), "Failed getting converter info");
        CheckError(AUGraphNodeInfo(player->graph, reverbNode, NULL, &player->reverbUnit), "Failed getting reverbUnit info");
        CheckError(AUGraphNodeInfo(player->graph, bassBoostNode, NULL, &player->bassBoostUnit), "Failed getting reverbUnit info");
        CheckError(AUGraphNodeInfo(player->graph, bassBoostConverterNode, NULL, &bassBoostConvertrunit), "Failed getting bassBoostConvertrunit info");
    }
    
    //some AU nodes take a stream format in float by default, while others take it in integers. So fix the issue by adding a converter
    {
        //Set conveter unit input format as eq preset unit asbd
        AudioStreamBasicDescription eqAsbd;
        UInt32 streamFormatSize = sizeof(eqAsbd);
        AudioUnitGetProperty(player->eqUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &eqAsbd, &streamFormatSize);
        AudioUnitSetProperty(convertrunit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &eqAsbd, streamFormatSize);
        
        //Set converter unit out put format as band eq unit asbd
        AudioStreamBasicDescription bandAsbd;
        UInt32 bandstreamFormatSize = sizeof(bandAsbd);
        AudioUnitGetProperty(player->bandEQUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &bandAsbd, &bandstreamFormatSize);
        AudioUnitSetProperty(convertrunit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &bandAsbd, bandstreamFormatSize);
    }
    //    Add converter for bass boost node
    {
        //Set conveter unit input format as eq preset unit asbd
        AudioStreamBasicDescription eqAsbd;
        UInt32 streamFormatSize = sizeof(eqAsbd);
        AudioUnitGetProperty(player->bandEQUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &eqAsbd, &streamFormatSize);
        AudioUnitSetProperty(bassBoostConvertrunit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &eqAsbd, streamFormatSize);
        
        //Set converter unit out put format as band eq unit asbd
        AudioStreamBasicDescription bandAsbd;
        UInt32 bandstreamFormatSize = sizeof(bandAsbd);
        AudioUnitGetProperty(player->bassBoostUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &bandAsbd, &bandstreamFormatSize);
        AudioUnitSetProperty(bassBoostConvertrunit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &bandAsbd, bandstreamFormatSize);
    }
    
    {
        //Connect Nodes
        
        CheckError(AUGraphConnectNodeInput(player->graph, filePlayerNode, 0, mixerNode, 0), "Failed Connect nodes (filePlayer - mixer)");
        CheckError(AUGraphConnectNodeInput(player->graph, mixerNode, 0, eqNode, 0), "Failed Connect nodes (filePlayer - mixer)");
        CheckError(AUGraphConnectNodeInput(player->graph, eqNode, 0, converterNode, 0), "Failed Connect nodes (eqNodeeqNode - bassBoostNode)");
        CheckError(AUGraphConnectNodeInput(player->graph, converterNode, 0, bandEQNode, 0), "Failed Connect nodes (bassBoostNode - converterNode)");
        CheckError(AUGraphConnectNodeInput(player->graph, bandEQNode, 0, bassBoostConverterNode, 0), "Failed Connect nodes (filePlayer - mixer)");
        CheckError(AUGraphConnectNodeInput(player->graph, bassBoostConverterNode, 0, bassBoostNode, 0), "Failed Connect nodes (filePlayer - mixer)");
        CheckError(AUGraphConnectNodeInput(player->graph, bassBoostNode, 0, outputNode, 0), "Failed Connect nodes (filePlayer - mixer)");
        //    CheckError(AUGraphConnectNodeInput(player->graph, reverbNode, 0, outputNode, 0), "Failed Connect nodes (mixer - output)");
    }
    {
        //to play audio in sleep mode.
        UInt32 maxFPS = 4096;
        AudioUnitSetProperty(player->filePlayerUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
        AudioUnitSetProperty(player->mxUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
        AudioUnitSetProperty(player->eqUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
        AudioUnitSetProperty(player->bandEQUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
        AudioUnitSetProperty(convertrunit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
        AudioUnitSetProperty(player->reverbUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
        AudioUnitSetProperty(player->bassBoostUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
        AudioUnitSetProperty(bassBoostConvertrunit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
    }
    CheckError(AUGraphInitialize(player->graph), "Faile graph initilize");
    CAShow(player->graph);
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

OSStatus playRenderNotify(void *                      inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *      inTimeStamp,
                          UInt32                      inBusNumber,
                          UInt32                      inNumberFrames,
                          AudioBufferList *           ioData) {
    if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
        double currentPlayTime =  [ currentPlaybackTime];
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

void addRenderNotifier(CPPlayer *player) {
    CheckError(AudioUnitAddRenderNotify(player->filePlayerUnit, &playRenderNotify, &player), "Failed add render notifier");
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








void initilizeGraph() {
    Boolean isinitilized;
    CheckError(AUGraphIsInitialized(globalPlayer.myPlayer.graph, &isinitilized), "Failed check in initilized");
    if (!isinitilized) {
        CheckError(AUGraphInitialize(globalPlayer.myPlayer.graph), "Failed un reinitilizing graph");
    }
}

Boolean isAUGraphIsRunning(AUGraph graph) {
    Boolean isRunning = false;
    if (graph != nil) {
        CheckError(AUGraphIsRunning(graph, &isRunning), "Failed checking is Augraph is running");
    }
    return isRunning;
}

void resetAudioFile() {
    if (globalPlayer.myPlayer.inputFile != nil) {
        AudioFileClose(globalPlayer.myPlayer.inputFile);
        globalPlayer->myPlayer.inputFile = nil;
    }
}

void resetFilePlayerUnit(Float64 currentFrame) {
    globalPlayer->myPlayer.playBackStartFrame = currentFrame;
    CheckError(AudioUnitRemoveRenderNotify(globalPlayer->myPlayer.filePlayerUnit, &playRenderNotify, &globalPlayer->myPlayer), "Failed remove render notifier");
    CheckError(AudioUnitReset(globalPlayer->myPlayer.filePlayerUnit, kAudioUnitScope_Global, 0), "Failed reset file player");
}

void resetGraph() {
    AUGraph graph = globalPlayer.myPlayer.graph;
    if (isAUGraphIsRunning(graph)) {
        CheckError(AUGraphStop(graph), "Failed stop AUGraph");
    }
    CheckError(AUGraphUninitialize(graph), "Failed un uninitilizing graph");
}

//Reset file player unit & audio file, to clear some memory
void reset(Float64 currentFrame) {
    resetFilePlayerUnit(currentFrame);
    resetAudioFile();
    resetGraph();
}

void closeGraph(CPPlayer *player) {
    reset(0.0);
    CheckError(AUGraphClose(player->graph), "Failed closing audio graph");
}

*/



