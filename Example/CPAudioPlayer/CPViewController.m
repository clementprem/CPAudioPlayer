//
//  CPViewController.m
//  CPAudioPlayer
//
//  Created by Clement Prem on 11/30/2014.
//  Copyright (c) 2014 Clement Prem. All rights reserved.
//

#import "CPViewController.h"
#import <CPAudioPlayer/CPAudioPlayer.h>
#import <CPAudioPlayer/CPAudioPlayerView.h>

@interface CPViewController () <CPAudioPlayerViewDelegate>

@property (nonatomic, strong) CPAudioPlayer *audioPlayer;
@property (nonatomic, strong) CPAudioPlayerView *playerView;
@property (nonatomic, strong) NSTimer *updateTimer;

@end

@implementation CPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];

    // Initialize the audio player
    self.audioPlayer = [[CPAudioPlayer alloc] init];

    // Create the player view
    CGRect playerFrame = CGRectMake(16, 60, self.view.bounds.size.width - 32, 500);
    self.playerView = [[CPAudioPlayerView alloc] initWithFrame:playerFrame];
    self.playerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    self.playerView.delegate = self;
    self.playerView.audioPlayer = self.audioPlayer;

    // Customize appearance (optional)
    self.playerView.accentColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.8 alpha:1.0];

    [self.view addSubview:self.playerView];

    // Load a sample audio file (replace with your audio file URL)
    // Example: Load from bundle
    NSURL *audioURL = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"mp3"];
    if (audioURL) {
        [self loadAudioFile:audioURL];
    }
}

- (void)loadAudioFile:(NSURL *)url
{
    Boolean isError = false;
    [self.audioPlayer setupAudioFileWithURL:url playBackDuration:0 isError:&isError];

    if (!isError) {
        self.playerView.duration = self.audioPlayer.playBackduration;
        self.playerView.trackTitle = [url.lastPathComponent stringByDeletingPathExtension];
        self.playerView.artistName = @"Unknown Artist";

        // Set up completion handler
        __weak typeof(self) weakSelf = self;
        [self.audioPlayer handleSongPlayingCompletion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.playerView.isPlaying = NO;
                weakSelf.playerView.currentTime = 0;
                [weakSelf stopUpdateTimer];
            });
        }];
    }
}

#pragma mark - Timer for playback updates

- (void)startUpdateTimer
{
    [self stopUpdateTimer];
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                        target:self
                                                      selector:@selector(updatePlaybackTime)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopUpdateTimer
{
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void)updatePlaybackTime
{
    self.playerView.currentTime = self.audioPlayer.currentPlaybackTime;
}

#pragma mark - CPAudioPlayerViewDelegate

- (void)audioPlayerViewDidTapPlay:(CPAudioPlayerView *)playerView
{
    [self.audioPlayer play];
    [self startUpdateTimer];
}

- (void)audioPlayerViewDidTapPause:(CPAudioPlayerView *)playerView
{
    [self.audioPlayer pause];
    [self stopUpdateTimer];
}

- (void)audioPlayerViewDidTapStop:(CPAudioPlayerView *)playerView
{
    [self.audioPlayer stop];
    [self stopUpdateTimer];
}

- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangePlaybackTime:(double)time
{
    // Time change is handled by the view when bound to audioPlayer
}

- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeEQBand:(NSInteger)band toValue:(float)value
{
    NSLog(@"EQ Band %ld changed to %.1f dB", (long)band, value);
}

- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeBassBoost:(float)value
{
    NSLog(@"Bass boost changed to %.1f", value);
}

- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeTreble:(float)value
{
    NSLog(@"Treble changed to %.1f", value);
}

- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeReverb:(float)value
{
    NSLog(@"Reverb changed to %.0f%%", value * 100);
}

- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeBalance:(float)value
{
    NSLog(@"Balance changed to %.2f", value);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [self stopUpdateTimer];
}

@end
