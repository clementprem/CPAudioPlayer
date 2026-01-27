//
//  CPAudioPlayerView.m
//  CPAudioPlayer
//
//  Modern audio player view with EQ and controls
//

#import "CPAudioPlayerView.h"
#import "CPAudioPlayer.h"

static NSArray<NSNumber *> *kDefaultEQFrequencies;
static NSDictionary<NSString *, NSArray<NSNumber *> *> *kEQPresets;

@interface CPEQSliderView : UIView
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *frequencyLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, assign) NSInteger bandIndex;
@property (nonatomic, copy) void (^valueChangedHandler)(float value, NSInteger band);
@end

@implementation CPEQSliderView

- (instancetype)initWithFrequency:(NSNumber *)frequency bandIndex:(NSInteger)index {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _bandIndex = index;
        [self setupWithFrequency:frequency];
    }
    return self;
}

- (void)setupWithFrequency:(NSNumber *)frequency {
    self.backgroundColor = [UIColor clearColor];

    // Frequency label at top
    _frequencyLabel = [[UILabel alloc] init];
    _frequencyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _frequencyLabel.textAlignment = NSTextAlignmentCenter;
    _frequencyLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    _frequencyLabel.textColor = [UIColor lightGrayColor];
    _frequencyLabel.text = [self formatFrequency:frequency.floatValue];
    [self addSubview:_frequencyLabel];

    // Vertical slider
    _slider = [[UISlider alloc] init];
    _slider.translatesAutoresizingMaskIntoConstraints = NO;
    _slider.minimumValue = -12.0;
    _slider.maximumValue = 12.0;
    _slider.value = 0.0;
    _slider.transform = CGAffineTransformMakeRotation(-M_PI_2);
    _slider.minimumTrackTintColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.8 alpha:1.0];
    _slider.maximumTrackTintColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    [_slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:_slider];

    // Value label at bottom
    _valueLabel = [[UILabel alloc] init];
    _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _valueLabel.textAlignment = NSTextAlignmentCenter;
    _valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:9 weight:UIFontWeightRegular];
    _valueLabel.textColor = [UIColor whiteColor];
    _valueLabel.text = @"0 dB";
    [self addSubview:_valueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_frequencyLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
        [_frequencyLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_frequencyLabel.widthAnchor constraintEqualToAnchor:self.widthAnchor],

        [_slider.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_slider.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_slider.widthAnchor constraintEqualToConstant:100],

        [_valueLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
        [_valueLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_valueLabel.widthAnchor constraintEqualToAnchor:self.widthAnchor],
    ]];
}

- (NSString *)formatFrequency:(float)freq {
    if (freq >= 1000) {
        return [NSString stringWithFormat:@"%.0fK", freq / 1000.0];
    }
    return [NSString stringWithFormat:@"%.0f", freq];
}

- (void)sliderValueChanged:(UISlider *)slider {
    _valueLabel.text = [NSString stringWithFormat:@"%.0f dB", slider.value];
    if (_valueChangedHandler) {
        _valueChangedHandler(slider.value, _bandIndex);
    }
}

- (void)setValue:(float)value {
    _slider.value = value;
    _valueLabel.text = [NSString stringWithFormat:@"%.0f dB", value];
}

- (float)value {
    return _slider.value;
}

- (void)setAccentColor:(UIColor *)color {
    _slider.minimumTrackTintColor = color;
}

@end

#pragma mark - CPAudioPlayerView

@interface CPAudioPlayerView ()

// Main containers
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStack;

// Track info section
@property (nonatomic, strong) UIView *trackInfoContainer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;

// Transport section
@property (nonatomic, strong) UIView *transportContainer;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UISlider *timeSlider;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *durationLabel;

// EQ section
@property (nonatomic, strong) UIView *eqContainer;
@property (nonatomic, strong) UILabel *eqTitleLabel;
@property (nonatomic, strong) UIButton *presetButton;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIStackView *eqSlidersStack;
@property (nonatomic, strong) NSMutableArray<CPEQSliderView *> *eqSliders;

// Effects section
@property (nonatomic, strong) UIView *effectsContainer;
@property (nonatomic, strong) UILabel *effectsTitleLabel;
@property (nonatomic, strong) UISlider *bassSlider;
@property (nonatomic, strong) UISlider *trebleSlider;
@property (nonatomic, strong) UISlider *reverbSlider;
@property (nonatomic, strong) UISlider *balanceSlider;
@property (nonatomic, strong) UILabel *bassValueLabel;
@property (nonatomic, strong) UILabel *trebleValueLabel;
@property (nonatomic, strong) UILabel *reverbValueLabel;
@property (nonatomic, strong) UILabel *balanceValueLabel;

// Internal state
@property (nonatomic, strong, readwrite) NSArray<NSNumber *> *eqFrequencies;
@property (nonatomic, strong, readwrite) NSArray<NSString *> *availablePresets;
@property (nonatomic, strong) NSTimer *playbackTimer;
@property (nonatomic, assign) BOOL isSeeking;

@end

@implementation CPAudioPlayerView

+ (void)initialize {
    if (self == [CPAudioPlayerView class]) {
        kDefaultEQFrequencies = @[@60, @150, @400, @1100, @3100, @8000, @16000];

        kEQPresets = @{
            @"Flat": @[@0, @0, @0, @0, @0, @0, @0],
            @"Bass Boost": @[@6, @4, @2, @0, @0, @0, @0],
            @"Treble Boost": @[@0, @0, @0, @0, @2, @4, @6],
            @"Rock": @[@4, @2, @-1, @0, @2, @4, @5],
            @"Pop": @[@-1, @1, @3, @4, @3, @1, @-1],
            @"Jazz": @[@3, @1, @-2, @0, @2, @4, @5],
            @"Classical": @[@4, @3, @0, @0, @0, @2, @4],
            @"Electronic": @[@5, @4, @0, @-2, @0, @4, @5],
            @"Hip Hop": @[@5, @4, @1, @0, @-1, @2, @3],
            @"Acoustic": @[@4, @2, @0, @1, @2, @3, @3],
            @"Vocal": @[@-2, @0, @2, @4, @3, @1, @0],
            @"Loudness": @[@5, @3, @0, @0, @0, @2, @4],
        };
    }
}

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame eqFrequencies:kDefaultEQFrequencies];
}

- (instancetype)initWithFrame:(CGRect)frame eqFrequencies:(NSArray<NSNumber *> *)frequencies {
    self = [super initWithFrame:frame];
    if (self) {
        _eqFrequencies = [frequencies copy];
        _eqSliders = [NSMutableArray array];
        _availablePresets = [kEQPresets.allKeys sortedArrayUsingSelector:@selector(localizedCompare:)];

        // Default appearance
        _accentColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.8 alpha:1.0];
        _viewBackgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
        _textColor = [UIColor whiteColor];
        _secondaryTextColor = [UIColor lightGrayColor];

        // Default layout options
        _showsTransportControls = YES;
        _showsTimeSlider = YES;
        _showsEqualizer = YES;
        _showsEffects = YES;
        _showsPresetButton = YES;
        _compactMode = NO;

        [self setupUI];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _eqFrequencies = kDefaultEQFrequencies;
        _eqSliders = [NSMutableArray array];
        _availablePresets = [kEQPresets.allKeys sortedArrayUsingSelector:@selector(localizedCompare:)];

        _accentColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.8 alpha:1.0];
        _viewBackgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
        _textColor = [UIColor whiteColor];
        _secondaryTextColor = [UIColor lightGrayColor];

        _showsTransportControls = YES;
        _showsTimeSlider = YES;
        _showsEqualizer = YES;
        _showsEffects = YES;
        _showsPresetButton = YES;
        _compactMode = NO;

        [self setupUI];
    }
    return self;
}

#pragma mark - UI Setup

- (void)setupUI {
    self.backgroundColor = _viewBackgroundColor;
    self.clipsToBounds = YES;
    self.layer.cornerRadius = 16;

    // Scroll view for content
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.showsVerticalScrollIndicator = YES;
    _scrollView.alwaysBounceVertical = YES;
    [self addSubview:_scrollView];

    // Main stack
    _mainStack = [[UIStackView alloc] init];
    _mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    _mainStack.axis = UILayoutConstraintAxisVertical;
    _mainStack.spacing = 20;
    _mainStack.alignment = UIStackViewAlignmentFill;
    [_scrollView addSubview:_mainStack];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [_mainStack.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:16],
        [_mainStack.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:16],
        [_mainStack.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-16],
        [_mainStack.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-16],
        [_mainStack.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-32],
    ]];

    [self setupTrackInfoSection];
    [self setupTransportSection];
    [self setupEQSection];
    [self setupEffectsSection];

    [self updateSectionVisibility];
}

- (void)setupTrackInfoSection {
    _trackInfoContainer = [[UIView alloc] init];
    _trackInfoContainer.translatesAutoresizingMaskIntoConstraints = NO;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    _titleLabel.textColor = _textColor;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.text = @"No Track Selected";
    [_trackInfoContainer addSubview:_titleLabel];

    _artistLabel = [[UILabel alloc] init];
    _artistLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _artistLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _artistLabel.textColor = _secondaryTextColor;
    _artistLabel.textAlignment = NSTextAlignmentCenter;
    _artistLabel.text = @"";
    [_trackInfoContainer addSubview:_artistLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:_trackInfoContainer.topAnchor],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_trackInfoContainer.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_trackInfoContainer.trailingAnchor],

        [_artistLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_artistLabel.leadingAnchor constraintEqualToAnchor:_trackInfoContainer.leadingAnchor],
        [_artistLabel.trailingAnchor constraintEqualToAnchor:_trackInfoContainer.trailingAnchor],
        [_artistLabel.bottomAnchor constraintEqualToAnchor:_trackInfoContainer.bottomAnchor],
    ]];

    [_mainStack addArrangedSubview:_trackInfoContainer];
}

- (void)setupTransportSection {
    _transportContainer = [[UIView alloc] init];
    _transportContainer.translatesAutoresizingMaskIntoConstraints = NO;

    // Time labels and slider
    _currentTimeLabel = [[UILabel alloc] init];
    _currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _currentTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    _currentTimeLabel.textColor = _secondaryTextColor;
    _currentTimeLabel.text = @"0:00";
    [_transportContainer addSubview:_currentTimeLabel];

    _durationLabel = [[UILabel alloc] init];
    _durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    _durationLabel.textColor = _secondaryTextColor;
    _durationLabel.textAlignment = NSTextAlignmentRight;
    _durationLabel.text = @"0:00";
    [_transportContainer addSubview:_durationLabel];

    _timeSlider = [[UISlider alloc] init];
    _timeSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _timeSlider.minimumValue = 0;
    _timeSlider.maximumValue = 1;
    _timeSlider.value = 0;
    _timeSlider.minimumTrackTintColor = _accentColor;
    _timeSlider.maximumTrackTintColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    [_timeSlider addTarget:self action:@selector(timeSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_timeSlider addTarget:self action:@selector(timeSliderTouchDown:) forControlEvents:UIControlEventTouchDown];
    [_timeSlider addTarget:self action:@selector(timeSliderTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [_transportContainer addSubview:_timeSlider];

    // Transport buttons
    UIStackView *buttonStack = [[UIStackView alloc] init];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.spacing = 32;
    buttonStack.alignment = UIStackViewAlignmentCenter;
    buttonStack.distribution = UIStackViewDistributionEqualCentering;
    [_transportContainer addSubview:buttonStack];

    _stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _stopButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_stopButton setImage:[self stopIcon] forState:UIControlStateNormal];
    _stopButton.tintColor = _textColor;
    [_stopButton addTarget:self action:@selector(stopTapped:) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:_stopButton];

    _playPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_playPauseButton setImage:[self playIcon] forState:UIControlStateNormal];
    _playPauseButton.tintColor = _accentColor;
    _playPauseButton.transform = CGAffineTransformMakeScale(1.5, 1.5);
    [_playPauseButton addTarget:self action:@selector(playPauseTapped:) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:_playPauseButton];

    // Placeholder for symmetry
    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [spacer.widthAnchor constraintEqualToConstant:44].active = YES;
    [buttonStack addArrangedSubview:spacer];

    [NSLayoutConstraint activateConstraints:@[
        [_currentTimeLabel.topAnchor constraintEqualToAnchor:_transportContainer.topAnchor],
        [_currentTimeLabel.leadingAnchor constraintEqualToAnchor:_transportContainer.leadingAnchor],

        [_durationLabel.topAnchor constraintEqualToAnchor:_transportContainer.topAnchor],
        [_durationLabel.trailingAnchor constraintEqualToAnchor:_transportContainer.trailingAnchor],

        [_timeSlider.topAnchor constraintEqualToAnchor:_currentTimeLabel.bottomAnchor constant:4],
        [_timeSlider.leadingAnchor constraintEqualToAnchor:_transportContainer.leadingAnchor],
        [_timeSlider.trailingAnchor constraintEqualToAnchor:_transportContainer.trailingAnchor],

        [buttonStack.topAnchor constraintEqualToAnchor:_timeSlider.bottomAnchor constant:16],
        [buttonStack.centerXAnchor constraintEqualToAnchor:_transportContainer.centerXAnchor],
        [buttonStack.bottomAnchor constraintEqualToAnchor:_transportContainer.bottomAnchor],

        [_stopButton.widthAnchor constraintEqualToConstant:44],
        [_stopButton.heightAnchor constraintEqualToConstant:44],
        [_playPauseButton.widthAnchor constraintEqualToConstant:44],
        [_playPauseButton.heightAnchor constraintEqualToConstant:44],
    ]];

    [_mainStack addArrangedSubview:_transportContainer];
}

- (void)setupEQSection {
    _eqContainer = [[UIView alloc] init];
    _eqContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _eqContainer.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    _eqContainer.layer.cornerRadius = 12;

    // Header with title and buttons
    UIStackView *headerStack = [[UIStackView alloc] init];
    headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.alignment = UIStackViewAlignmentCenter;
    headerStack.distribution = UIStackViewDistributionEqualSpacing;
    [_eqContainer addSubview:headerStack];

    _eqTitleLabel = [[UILabel alloc] init];
    _eqTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eqTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _eqTitleLabel.textColor = _textColor;
    _eqTitleLabel.text = @"Equalizer";
    [headerStack addArrangedSubview:_eqTitleLabel];

    UIStackView *buttonGroup = [[UIStackView alloc] init];
    buttonGroup.axis = UILayoutConstraintAxisHorizontal;
    buttonGroup.spacing = 12;
    [headerStack addArrangedSubview:buttonGroup];

    _presetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_presetButton setTitle:@"Presets" forState:UIControlStateNormal];
    _presetButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _presetButton.tintColor = _accentColor;
    [_presetButton addTarget:self action:@selector(presetTapped:) forControlEvents:UIControlEventTouchUpInside];
    [buttonGroup addArrangedSubview:_presetButton];

    _resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_resetButton setTitle:@"Reset" forState:UIControlStateNormal];
    _resetButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _resetButton.tintColor = _secondaryTextColor;
    [_resetButton addTarget:self action:@selector(resetEQTapped:) forControlEvents:UIControlEventTouchUpInside];
    [buttonGroup addArrangedSubview:_resetButton];

    // EQ sliders
    _eqSlidersStack = [[UIStackView alloc] init];
    _eqSlidersStack.translatesAutoresizingMaskIntoConstraints = NO;
    _eqSlidersStack.axis = UILayoutConstraintAxisHorizontal;
    _eqSlidersStack.distribution = UIStackViewDistributionFillEqually;
    _eqSlidersStack.alignment = UIStackViewAlignmentFill;
    _eqSlidersStack.spacing = 4;
    [_eqContainer addSubview:_eqSlidersStack];

    for (NSInteger i = 0; i < _eqFrequencies.count; i++) {
        CPEQSliderView *sliderView = [[CPEQSliderView alloc] initWithFrequency:_eqFrequencies[i] bandIndex:i];
        sliderView.translatesAutoresizingMaskIntoConstraints = NO;
        [sliderView setAccentColor:_accentColor];

        __weak typeof(self) weakSelf = self;
        sliderView.valueChangedHandler = ^(float value, NSInteger band) {
            [weakSelf eqBandChanged:value band:band];
        };

        [_eqSlidersStack addArrangedSubview:sliderView];
        [_eqSliders addObject:sliderView];
    }

    CGFloat eqHeight = _compactMode ? 140 : 160;

    [NSLayoutConstraint activateConstraints:@[
        [headerStack.topAnchor constraintEqualToAnchor:_eqContainer.topAnchor constant:12],
        [headerStack.leadingAnchor constraintEqualToAnchor:_eqContainer.leadingAnchor constant:12],
        [headerStack.trailingAnchor constraintEqualToAnchor:_eqContainer.trailingAnchor constant:-12],

        [_eqSlidersStack.topAnchor constraintEqualToAnchor:headerStack.bottomAnchor constant:8],
        [_eqSlidersStack.leadingAnchor constraintEqualToAnchor:_eqContainer.leadingAnchor constant:8],
        [_eqSlidersStack.trailingAnchor constraintEqualToAnchor:_eqContainer.trailingAnchor constant:-8],
        [_eqSlidersStack.bottomAnchor constraintEqualToAnchor:_eqContainer.bottomAnchor constant:-8],
        [_eqSlidersStack.heightAnchor constraintEqualToConstant:eqHeight],
    ]];

    [_mainStack addArrangedSubview:_eqContainer];
}

- (void)setupEffectsSection {
    _effectsContainer = [[UIView alloc] init];
    _effectsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _effectsContainer.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    _effectsContainer.layer.cornerRadius = 12;

    _effectsTitleLabel = [[UILabel alloc] init];
    _effectsTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _effectsTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _effectsTitleLabel.textColor = _textColor;
    _effectsTitleLabel.text = @"Effects";
    [_effectsContainer addSubview:_effectsTitleLabel];

    UIStackView *effectsStack = [[UIStackView alloc] init];
    effectsStack.translatesAutoresizingMaskIntoConstraints = NO;
    effectsStack.axis = UILayoutConstraintAxisVertical;
    effectsStack.spacing = 16;
    [_effectsContainer addSubview:effectsStack];

    // Bass
    UIView *bassRow = [self createEffectRowWithTitle:@"Bass" slider:&_bassSlider valueLabel:&_bassValueLabel min:0 max:10 action:@selector(bassChanged:)];
    [effectsStack addArrangedSubview:bassRow];

    // Treble
    UIView *trebleRow = [self createEffectRowWithTitle:@"Treble" slider:&_trebleSlider valueLabel:&_trebleValueLabel min:0 max:10 action:@selector(trebleChanged:)];
    [effectsStack addArrangedSubview:trebleRow];

    // Reverb
    UIView *reverbRow = [self createEffectRowWithTitle:@"Reverb" slider:&_reverbSlider valueLabel:&_reverbValueLabel min:0 max:1 action:@selector(reverbChanged:)];
    [effectsStack addArrangedSubview:reverbRow];

    // Balance
    UIView *balanceRow = [self createEffectRowWithTitle:@"Balance" slider:&_balanceSlider valueLabel:&_balanceValueLabel min:-1 max:1 action:@selector(balanceChanged:)];
    _balanceSlider.value = 0;
    _balanceValueLabel.text = @"C";
    [effectsStack addArrangedSubview:balanceRow];

    [NSLayoutConstraint activateConstraints:@[
        [_effectsTitleLabel.topAnchor constraintEqualToAnchor:_effectsContainer.topAnchor constant:12],
        [_effectsTitleLabel.leadingAnchor constraintEqualToAnchor:_effectsContainer.leadingAnchor constant:12],

        [effectsStack.topAnchor constraintEqualToAnchor:_effectsTitleLabel.bottomAnchor constant:12],
        [effectsStack.leadingAnchor constraintEqualToAnchor:_effectsContainer.leadingAnchor constant:12],
        [effectsStack.trailingAnchor constraintEqualToAnchor:_effectsContainer.trailingAnchor constant:-12],
        [effectsStack.bottomAnchor constraintEqualToAnchor:_effectsContainer.bottomAnchor constant:-12],
    ]];

    [_mainStack addArrangedSubview:_effectsContainer];
}

- (UIView *)createEffectRowWithTitle:(NSString *)title slider:(UISlider **)slider valueLabel:(UILabel **)valueLabel min:(float)min max:(float)max action:(SEL)action {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    label.textColor = _secondaryTextColor;
    label.text = title;
    [row addSubview:label];

    *slider = [[UISlider alloc] init];
    (*slider).translatesAutoresizingMaskIntoConstraints = NO;
    (*slider).minimumValue = min;
    (*slider).maximumValue = max;
    (*slider).value = 0;
    (*slider).minimumTrackTintColor = _accentColor;
    (*slider).maximumTrackTintColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    [(*slider) addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [row addSubview:*slider];

    *valueLabel = [[UILabel alloc] init];
    (*valueLabel).translatesAutoresizingMaskIntoConstraints = NO;
    (*valueLabel).font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    (*valueLabel).textColor = _textColor;
    (*valueLabel).textAlignment = NSTextAlignmentRight;
    (*valueLabel).text = @"0";
    [row addSubview:*valueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.widthAnchor constraintEqualToConstant:60],

        [(*slider).leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:8],
        [(*slider).centerYAnchor constraintEqualToAnchor:row.centerYAnchor],

        [(*valueLabel).leadingAnchor constraintEqualToAnchor:(*slider).trailingAnchor constant:8],
        [(*valueLabel).trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [(*valueLabel).centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [(*valueLabel).widthAnchor constraintEqualToConstant:40],

        [row.heightAnchor constraintEqualToConstant:32],
    ]];

    return row;
}

#pragma mark - Icons

- (UIImage *)playIcon {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24, 24), NO, 0);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(6, 4)];
    [path addLineToPoint:CGPointMake(20, 12)];
    [path addLineToPoint:CGPointMake(6, 20)];
    [path closePath];
    [[UIColor blackColor] setFill];
    [path fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *)pauseIcon {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24, 24), NO, 0);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 4, 5, 16) cornerRadius:1]];
    [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(14, 4, 5, 16) cornerRadius:1]];
    [[UIColor blackColor] setFill];
    [path fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *)stopIcon {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24, 24), NO, 0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 5, 14, 14) cornerRadius:2];
    [[UIColor blackColor] setFill];
    [path fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

#pragma mark - Actions

- (void)playPauseTapped:(UIButton *)sender {
    if (_isPlaying) {
        [_audioPlayer pause];
        if ([_delegate respondsToSelector:@selector(audioPlayerViewDidTapPause:)]) {
            [_delegate audioPlayerViewDidTapPause:self];
        }
    } else {
        [_audioPlayer play];
        if ([_delegate respondsToSelector:@selector(audioPlayerViewDidTapPlay:)]) {
            [_delegate audioPlayerViewDidTapPlay:self];
        }
    }
    self.isPlaying = !_isPlaying;
}

- (void)stopTapped:(UIButton *)sender {
    [_audioPlayer stop];
    self.isPlaying = NO;
    self.currentTime = 0;
    if ([_delegate respondsToSelector:@selector(audioPlayerViewDidTapStop:)]) {
        [_delegate audioPlayerViewDidTapStop:self];
    }
}

- (void)timeSliderChanged:(UISlider *)slider {
    double time = slider.value * _duration;
    _currentTimeLabel.text = [self formatTime:time];

    if ([_delegate respondsToSelector:@selector(audioPlayerView:didChangePlaybackTime:)]) {
        [_delegate audioPlayerView:self didChangePlaybackTime:time];
    }
}

- (void)timeSliderTouchDown:(UISlider *)slider {
    _isSeeking = YES;
}

- (void)timeSliderTouchUp:(UISlider *)slider {
    _isSeeking = NO;
    double time = slider.value * _duration;
    [_audioPlayer setPlayBackTime:time];
}

- (void)presetTapped:(UIButton *)sender {
    [self showPresetPicker];
}

- (void)resetEQTapped:(UIButton *)sender {
    [self resetEQ];
}

- (void)eqBandChanged:(float)value band:(NSInteger)band {
    if (_audioPlayer) {
        NSMutableArray *values = [NSMutableArray arrayWithCapacity:_eqSliders.count];
        for (CPEQSliderView *slider in _eqSliders) {
            [values addObject:@(slider.value)];
        }
        [_audioPlayer setBandValue:values];
    }

    if ([_delegate respondsToSelector:@selector(audioPlayerView:didChangeEQBand:toValue:)]) {
        [_delegate audioPlayerView:self didChangeEQBand:band toValue:value];
    }
}

- (void)bassChanged:(UISlider *)slider {
    _bassValueLabel.text = [NSString stringWithFormat:@"%.1f", slider.value];

    if (_audioPlayer) {
        [_audioPlayer setbassBoost:slider.value];
    }

    if ([_delegate respondsToSelector:@selector(audioPlayerView:didChangeBassBoost:)]) {
        [_delegate audioPlayerView:self didChangeBassBoost:slider.value];
    }
}

- (void)trebleChanged:(UISlider *)slider {
    _trebleValueLabel.text = [NSString stringWithFormat:@"%.1f", slider.value];

    if (_audioPlayer) {
        [_audioPlayer setTreble:slider.value];
    }

    if ([_delegate respondsToSelector:@selector(audioPlayerView:didChangeTreble:)]) {
        [_delegate audioPlayerView:self didChangeTreble:slider.value];
    }
}

- (void)reverbChanged:(UISlider *)slider {
    _reverbValueLabel.text = [NSString stringWithFormat:@"%.0f%%", slider.value * 100];

    if (_audioPlayer) {
        [_audioPlayer setRoomSize:slider.value];
    }

    if ([_delegate respondsToSelector:@selector(audioPlayerView:didChangeReverb:)]) {
        [_delegate audioPlayerView:self didChangeReverb:slider.value];
    }
}

- (void)balanceChanged:(UISlider *)slider {
    float value = slider.value;
    if (fabs(value) < 0.05) {
        value = 0;
        slider.value = 0;
    }

    if (value == 0) {
        _balanceValueLabel.text = @"C";
    } else if (value < 0) {
        _balanceValueLabel.text = [NSString stringWithFormat:@"L%.0f", fabs(value) * 100];
    } else {
        _balanceValueLabel.text = [NSString stringWithFormat:@"R%.0f", value * 100];
    }

    if (_audioPlayer) {
        [_audioPlayer setChannelBalance:value];
    }

    if ([_delegate respondsToSelector:@selector(audioPlayerView:didChangeBalance:)]) {
        [_delegate audioPlayerView:self didChangeBalance:value];
    }
}

#pragma mark - Public Methods

- (float)valueForEQBand:(NSInteger)band {
    if (band < 0 || band >= _eqSliders.count) return 0;
    return _eqSliders[band].value;
}

- (void)setEQValue:(float)value forBand:(NSInteger)band {
    if (band < 0 || band >= _eqSliders.count) return;
    [_eqSliders[band] setValue:value];
}

- (void)setEQValues:(NSArray<NSNumber *> *)values {
    for (NSInteger i = 0; i < MIN(values.count, _eqSliders.count); i++) {
        [_eqSliders[i] setValue:values[i].floatValue];
    }

    if (_audioPlayer) {
        [_audioPlayer setBandValue:values];
    }
}

- (void)resetEQ {
    for (CPEQSliderView *slider in _eqSliders) {
        [slider setValue:0];
    }

    if (_audioPlayer) {
        NSMutableArray *zeros = [NSMutableArray arrayWithCapacity:_eqSliders.count];
        for (NSInteger i = 0; i < _eqSliders.count; i++) {
            [zeros addObject:@0];
        }
        [_audioPlayer setBandValue:zeros];
    }
}

- (void)applyPreset:(NSString *)presetName {
    NSArray<NSNumber *> *values = kEQPresets[presetName];
    if (values) {
        [self setEQValues:values];
    }
}

- (void)showPresetPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"EQ Presets"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *preset in _availablePresets) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:preset
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            [self applyPreset:preset];
        }];
        [alert addAction:action];
    }

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
    [alert addAction:cancel];

    // Find the presenting view controller
    UIViewController *presenter = [self findViewController];
    if (presenter) {
        // For iPad
        alert.popoverPresentationController.sourceView = _presetButton;
        alert.popoverPresentationController.sourceRect = _presetButton.bounds;
        [presenter presentViewController:alert animated:YES completion:nil];
    }
}

- (UIViewController *)findViewController {
    UIResponder *responder = self;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

#pragma mark - Property Setters

- (void)setIsPlaying:(BOOL)isPlaying {
    _isPlaying = isPlaying;
    UIImage *icon = isPlaying ? [self pauseIcon] : [self playIcon];
    [_playPauseButton setImage:icon forState:UIControlStateNormal];
}

- (void)setDuration:(double)duration {
    _duration = duration;
    _durationLabel.text = [self formatTime:duration];
}

- (void)setCurrentTime:(double)currentTime {
    _currentTime = currentTime;
    if (!_isSeeking) {
        _currentTimeLabel.text = [self formatTime:currentTime];
        if (_duration > 0) {
            _timeSlider.value = currentTime / _duration;
        }
    }
}

- (void)setTrackTitle:(NSString *)trackTitle {
    _trackTitle = [trackTitle copy];
    _titleLabel.text = trackTitle ?: @"No Track Selected";
}

- (void)setArtistName:(NSString *)artistName {
    _artistName = [artistName copy];
    _artistLabel.text = artistName ?: @"";
}

- (void)setBassBoost:(float)bassBoost {
    _bassSlider.value = bassBoost;
    _bassValueLabel.text = [NSString stringWithFormat:@"%.1f", bassBoost];
}

- (float)bassBoost {
    return _bassSlider.value;
}

- (void)setTreble:(float)treble {
    _trebleSlider.value = treble;
    _trebleValueLabel.text = [NSString stringWithFormat:@"%.1f", treble];
}

- (float)treble {
    return _trebleSlider.value;
}

- (void)setReverb:(float)reverb {
    _reverbSlider.value = reverb;
    _reverbValueLabel.text = [NSString stringWithFormat:@"%.0f%%", reverb * 100];
}

- (float)reverb {
    return _reverbSlider.value;
}

- (void)setBalance:(float)balance {
    _balanceSlider.value = balance;
    if (balance == 0) {
        _balanceValueLabel.text = @"C";
    } else if (balance < 0) {
        _balanceValueLabel.text = [NSString stringWithFormat:@"L%.0f", fabs(balance) * 100];
    } else {
        _balanceValueLabel.text = [NSString stringWithFormat:@"R%.0f", balance * 100];
    }
}

- (float)balance {
    return _balanceSlider.value;
}

- (void)setAudioPlayer:(CPAudioPlayer *)audioPlayer {
    _audioPlayer = audioPlayer;

    if (audioPlayer) {
        // Sync UI with player state
        self.bassBoost = [audioPlayer getBassBoost];
        self.treble = [audioPlayer getTreble];
        self.reverb = [audioPlayer getRommSize];
        self.balance = [audioPlayer getChannelBalance];
        self.duration = audioPlayer.playBackduration;

        // Sync EQ values
        for (NSInteger i = 0; i < _eqSliders.count; i++) {
            float value = [audioPlayer getValueForBand:i];
            [_eqSliders[i] setValue:value];
        }
    }
}

- (void)setAccentColor:(UIColor *)accentColor {
    _accentColor = accentColor;
    _timeSlider.minimumTrackTintColor = accentColor;
    _bassSlider.minimumTrackTintColor = accentColor;
    _trebleSlider.minimumTrackTintColor = accentColor;
    _reverbSlider.minimumTrackTintColor = accentColor;
    _balanceSlider.minimumTrackTintColor = accentColor;
    _playPauseButton.tintColor = accentColor;
    _presetButton.tintColor = accentColor;

    for (CPEQSliderView *slider in _eqSliders) {
        [slider setAccentColor:accentColor];
    }
}

#pragma mark - Layout Options

- (void)setShowsTransportControls:(BOOL)showsTransportControls {
    _showsTransportControls = showsTransportControls;
    [self updateSectionVisibility];
}

- (void)setShowsTimeSlider:(BOOL)showsTimeSlider {
    _showsTimeSlider = showsTimeSlider;
    _timeSlider.hidden = !showsTimeSlider;
    _currentTimeLabel.hidden = !showsTimeSlider;
    _durationLabel.hidden = !showsTimeSlider;
}

- (void)setShowsEqualizer:(BOOL)showsEqualizer {
    _showsEqualizer = showsEqualizer;
    [self updateSectionVisibility];
}

- (void)setShowsEffects:(BOOL)showsEffects {
    _showsEffects = showsEffects;
    [self updateSectionVisibility];
}

- (void)setShowsPresetButton:(BOOL)showsPresetButton {
    _showsPresetButton = showsPresetButton;
    _presetButton.hidden = !showsPresetButton;
}

- (void)updateSectionVisibility {
    _transportContainer.hidden = !_showsTransportControls;
    _eqContainer.hidden = !_showsEqualizer;
    _effectsContainer.hidden = !_showsEffects;
}

#pragma mark - Helpers

- (NSString *)formatTime:(double)seconds {
    int mins = (int)seconds / 60;
    int secs = (int)seconds % 60;
    return [NSString stringWithFormat:@"%d:%02d", mins, secs];
}

@end
