//
//  CPAudioPlayerView.h
//  CPAudioPlayer
//
//  Modern audio player view with EQ and controls
//

#import <UIKit/UIKit.h>

@class CPAudioPlayer;
@class CPAudioPlayerView;

NS_ASSUME_NONNULL_BEGIN

@protocol CPAudioPlayerViewDelegate <NSObject>

@optional
- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangePlaybackTime:(double)time;
- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeEQBand:(NSInteger)band toValue:(float)value;
- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeBassBoost:(float)value;
- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeTreble:(float)value;
- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeReverb:(float)value;
- (void)audioPlayerView:(CPAudioPlayerView *)playerView didChangeBalance:(float)value;
- (void)audioPlayerViewDidTapPlay:(CPAudioPlayerView *)playerView;
- (void)audioPlayerViewDidTapPause:(CPAudioPlayerView *)playerView;
- (void)audioPlayerViewDidTapStop:(CPAudioPlayerView *)playerView;

@end

/**
 CPAudioPlayerView provides a modern UI for controlling audio playback
 and equalizer settings. It can be used standalone with delegate callbacks
 or directly bound to a CPAudioPlayer instance.
 */
@interface CPAudioPlayerView : UIView

/// The audio player instance to control. When set, the view automatically
/// updates the player's settings in response to user interactions.
@property (nonatomic, weak, nullable) CPAudioPlayer *audioPlayer;

/// Delegate for receiving control change notifications
@property (nonatomic, weak, nullable) id<CPAudioPlayerViewDelegate> delegate;

/// The frequencies for each EQ band (read-only, set during initialization)
@property (nonatomic, strong, readonly) NSArray<NSNumber *> *eqFrequencies;

/// Whether the player is currently playing (updates play/pause button state)
@property (nonatomic, assign) BOOL isPlaying;

/// Total duration of the current track in seconds
@property (nonatomic, assign) double duration;

/// Current playback time in seconds
@property (nonatomic, assign) double currentTime;

/// Track title to display (optional)
@property (nonatomic, copy, nullable) NSString *trackTitle;

/// Artist name to display (optional)
@property (nonatomic, copy, nullable) NSString *artistName;

#pragma mark - Appearance Customization

/// Primary accent color for sliders and buttons (default: system teal)
@property (nonatomic, strong) UIColor *accentColor;

/// Background color of the view (default: dark gray)
@property (nonatomic, strong) UIColor *viewBackgroundColor;

/// Text color for labels (default: white)
@property (nonatomic, strong) UIColor *textColor;

/// Secondary text color for less prominent labels (default: light gray)
@property (nonatomic, strong) UIColor *secondaryTextColor;

#pragma mark - Initialization

/// Creates a player view with the default 7-band EQ frequencies
- (instancetype)initWithFrame:(CGRect)frame;

/// Creates a player view with custom EQ frequencies
/// @param frame The frame for the view
/// @param frequencies Array of frequency values for EQ bands (e.g., @[@60, @150, @400, @1100, @3100, @8000, @16000])
- (instancetype)initWithFrame:(CGRect)frame eqFrequencies:(NSArray<NSNumber *> *)frequencies;

#pragma mark - EQ Control

/// Get the current value for an EQ band
/// @param band The band index (0-based)
/// @return The current gain value in dB
- (float)valueForEQBand:(NSInteger)band;

/// Set the value for an EQ band
/// @param value The gain value in dB
/// @param band The band index (0-based)
- (void)setEQValue:(float)value forBand:(NSInteger)band;

/// Set all EQ band values at once
/// @param values Array of gain values in dB
- (void)setEQValues:(NSArray<NSNumber *> *)values;

/// Reset all EQ bands to 0 dB
- (void)resetEQ;

#pragma mark - Effect Controls

/// Current bass boost value (0-10)
@property (nonatomic, assign) float bassBoost;

/// Current treble value (0-10)
@property (nonatomic, assign) float treble;

/// Current reverb/room size value (0-1)
@property (nonatomic, assign) float reverb;

/// Current channel balance (-1 left, 0 center, +1 right)
@property (nonatomic, assign) float balance;

#pragma mark - Presets

/// Array of available EQ preset names
@property (nonatomic, strong, readonly) NSArray<NSString *> *availablePresets;

/// Apply a built-in EQ preset
/// @param presetName The name of the preset to apply
- (void)applyPreset:(NSString *)presetName;

/// Show preset selection UI
- (void)showPresetPicker;

#pragma mark - Layout Options

/// Whether to show the transport controls (play/pause/stop). Default: YES
@property (nonatomic, assign) BOOL showsTransportControls;

/// Whether to show the time/seek slider. Default: YES
@property (nonatomic, assign) BOOL showsTimeSlider;

/// Whether to show the EQ section. Default: YES
@property (nonatomic, assign) BOOL showsEqualizer;

/// Whether to show the effects section (bass, treble, reverb, balance). Default: YES
@property (nonatomic, assign) BOOL showsEffects;

/// Whether to show the preset button. Default: YES
@property (nonatomic, assign) BOOL showsPresetButton;

/// Compact mode reduces vertical space by using smaller controls. Default: NO
@property (nonatomic, assign) BOOL compactMode;

@end

NS_ASSUME_NONNULL_END
