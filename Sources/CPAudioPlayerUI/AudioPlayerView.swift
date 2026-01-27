//
//  AudioPlayerView.swift
//  CPAudioPlayer
//
//  SwiftUI view for audio player with EQ and controls
//

import SwiftUI

// MARK: - Main Audio Player View

@available(iOS 16.0, *)
public struct AudioPlayerView: View {

    @ObservedObject var player: AudioPlayer

    // Configuration
    public var accentColor: Color
    public var showsTransportControls: Bool
    public var showsTimeSlider: Bool
    public var showsEqualizer: Bool
    public var showsEffects: Bool
    public var showsPresets: Bool
    public var compactMode: Bool

    @State private var showingPresetPicker = false

    public init(
        player: AudioPlayer,
        accentColor: Color = Color(red: 0, green: 0.8, blue: 0.8),
        showsTransportControls: Bool = true,
        showsTimeSlider: Bool = true,
        showsEqualizer: Bool = true,
        showsEffects: Bool = true,
        showsPresets: Bool = true,
        compactMode: Bool = false
    ) {
        self.player = player
        self.accentColor = accentColor
        self.showsTransportControls = showsTransportControls
        self.showsTimeSlider = showsTimeSlider
        self.showsEqualizer = showsEqualizer
        self.showsEffects = showsEffects
        self.showsPresets = showsPresets
        self.compactMode = compactMode
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Track Info
                TrackInfoSection(
                    title: player.trackTitle,
                    artist: player.artistName
                )

                // Transport Controls
                if showsTransportControls {
                    TransportSection(
                        player: player,
                        accentColor: accentColor,
                        showsTimeSlider: showsTimeSlider
                    )
                }

                // Equalizer
                if showsEqualizer {
                    EqualizerSection(
                        player: player,
                        accentColor: accentColor,
                        showsPresets: showsPresets,
                        compactMode: compactMode,
                        showingPresetPicker: $showingPresetPicker
                    )
                }

                // Effects
                if showsEffects {
                    EffectsSection(
                        player: player,
                        accentColor: accentColor
                    )
                }
            }
            .padding()
        }
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingPresetPicker) {
            PresetPickerView(player: player, accentColor: accentColor)
        }
    }
}

// MARK: - Track Info Section

@available(iOS 16.0, *)
struct TrackInfoSection: View {
    let title: String
    let artist: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title.isEmpty ? "No Track Selected" : title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            if !artist.isEmpty {
                Text(artist)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Transport Section

@available(iOS 16.0, *)
struct TransportSection: View {
    @ObservedObject var player: AudioPlayer
    let accentColor: Color
    let showsTimeSlider: Bool

    @State private var isSeeking = false
    @State private var seekValue: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            if showsTimeSlider {
                // Time Slider
                VStack(spacing: 4) {
                    HStack {
                        Text(player.currentTimeFormatted)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)

                        Spacer()

                        Text(player.durationFormatted)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    Slider(
                        value: Binding(
                            get: { isSeeking ? seekValue : player.progress },
                            set: { newValue in
                                seekValue = newValue
                                isSeeking = true
                            }
                        ),
                        in: 0...1,
                        onEditingChanged: { editing in
                            if !editing {
                                player.seek(toPercentage: seekValue)
                                isSeeking = false
                            }
                        }
                    )
                    .accentColor(accentColor)
                }
            }

            // Play/Pause/Stop Buttons
            HStack(spacing: 32) {
                Button(action: { player.stop() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)

                Button(action: { player.togglePlayPause() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor)
                }
                .frame(width: 54, height: 54)

                // Placeholder for symmetry
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
    }
}

// MARK: - Equalizer Section

@available(iOS 16.0, *)
struct EqualizerSection: View {
    @ObservedObject var player: AudioPlayer
    let accentColor: Color
    let showsPresets: Bool
    let compactMode: Bool
    @Binding var showingPresetPicker: Bool

    private let frequencies = AudioPlayer.defaultFrequencies

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Equalizer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if showsPresets {
                    Button("Presets") {
                        showingPresetPicker = true
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(accentColor)
                }

                Button("Reset") {
                    player.resetEQ()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
            }

            // EQ Sliders
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    EQBandSlider(
                        value: Binding(
                            get: { player.eqBands[index] },
                            set: { player.setEQ(value: $0, forBand: index) }
                        ),
                        frequency: frequencies[index],
                        accentColor: accentColor,
                        compact: compactMode
                    )
                }
            }
            .frame(height: compactMode ? 140 : 160)
        }
        .padding(12)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - EQ Band Slider

@available(iOS 16.0, *)
struct EQBandSlider: View {
    @Binding var value: Float
    let frequency: Float
    let accentColor: Color
    let compact: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Frequency label
            Text(formatFrequency(frequency))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)

            // Vertical slider
            GeometryReader { geometry in
                ZStack {
                    // Track background
                    Capsule()
                        .fill(Color(white: 0.3))
                        .frame(width: 4)

                    // Fill
                    Capsule()
                        .fill(accentColor)
                        .frame(width: 4, height: fillHeight(for: geometry.size.height))
                        .offset(y: fillOffset(for: geometry.size.height))

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(y: thumbOffset(for: geometry.size.height))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    let newValue = valueFromPosition(
                                        gesture.location.y,
                                        height: geometry.size.height
                                    )
                                    value = newValue
                                }
                        )
                }
                .frame(maxWidth: .infinity)
            }

            // Value label
            Text(String(format: "%.0f", value))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private func formatFrequency(_ freq: Float) -> String {
        if freq >= 1000 {
            return String(format: "%.0fK", freq / 1000)
        }
        return String(format: "%.0f", freq)
    }

    private func normalizedValue() -> CGFloat {
        // Convert -12 to +12 range to 0-1
        CGFloat((value + 12) / 24)
    }

    private func thumbOffset(for height: CGFloat) -> CGFloat {
        let usableHeight = height - 16
        let normalized = normalizedValue()
        return (0.5 - normalized) * usableHeight
    }

    private func fillHeight(for height: CGFloat) -> CGFloat {
        let usableHeight = height - 16
        return abs(normalizedValue() - 0.5) * usableHeight
    }

    private func fillOffset(for height: CGFloat) -> CGFloat {
        let normalized = normalizedValue()
        if normalized >= 0.5 {
            return (0.5 - normalized) * (height - 16) / 2
        } else {
            return (0.5 - normalized) * (height - 16) / 2
        }
    }

    private func valueFromPosition(_ y: CGFloat, height: CGFloat) -> Float {
        let usableHeight = height - 16
        let normalized = 1 - ((y - 8) / usableHeight)
        let clamped = max(0, min(1, normalized))
        return Float(clamped * 24 - 12)
    }
}

// MARK: - Effects Section

@available(iOS 16.0, *)
struct EffectsSection: View {
    @ObservedObject var player: AudioPlayer
    let accentColor: Color

    var body: some View {
        VStack(spacing: 12) {
            Text("Effects")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                EffectSlider(
                    label: "Bass",
                    value: $player.bassBoost,
                    range: 0...10,
                    accentColor: accentColor,
                    formatValue: { String(format: "%.1f", $0) }
                )

                EffectSlider(
                    label: "Treble",
                    value: $player.treble,
                    range: 0...10,
                    accentColor: accentColor,
                    formatValue: { String(format: "%.1f", $0) }
                )

                EffectSlider(
                    label: "Reverb",
                    value: $player.reverb,
                    range: 0...1,
                    accentColor: accentColor,
                    formatValue: { String(format: "%.0f%%", $0 * 100) }
                )

                EffectSlider(
                    label: "Balance",
                    value: $player.balance,
                    range: -1...1,
                    accentColor: accentColor,
                    formatValue: { value in
                        if abs(value) < 0.05 {
                            return "C"
                        } else if value < 0 {
                            return String(format: "L%.0f", abs(value) * 100)
                        } else {
                            return String(format: "R%.0f", value * 100)
                        }
                    }
                )
            }
        }
        .padding(12)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Effect Slider

@available(iOS 16.0, *)
struct EffectSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let accentColor: Color
    let formatValue: (Float) -> String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 60, alignment: .leading)

            Slider(
                value: $value,
                in: range
            )
            .accentColor(accentColor)

            Text(formatValue(value))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Preset Picker View

@available(iOS 16.0, *)
struct PresetPickerView: View {
    @ObservedObject var player: AudioPlayer
    let accentColor: Color
    @Environment(\.presentationMode) var presentationMode

    private var presetNames: [String] {
        AudioPlayer.presets.keys.sorted()
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(presetNames, id: \.self) { preset in
                    Button(action: {
                        player.applyPreset(preset)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(preset)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("EQ Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
    }
}

// MARK: - Compact Audio Player View

@available(iOS 16.0, *)
public struct CompactAudioPlayerView: View {
    @ObservedObject var player: AudioPlayer
    var accentColor: Color

    @State private var showingFullPlayer = false

    public init(player: AudioPlayer, accentColor: Color = Color(red: 0, green: 0.8, blue: 0.8)) {
        self.player = player
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(white: 0.3))

                    Rectangle()
                        .fill(accentColor)
                        .frame(width: geometry.size.width * CGFloat(player.progress))
                }
            }
            .frame(height: 3)
            .clipShape(Capsule())

            HStack(spacing: 12) {
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.trackTitle.isEmpty ? "No Track" : player.trackTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if !player.artistName.isEmpty {
                        Text(player.artistName)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Play/Pause
                Button(action: { player.togglePlayPause() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                }
                .frame(width: 44, height: 44)

                // Expand button
                Button(action: { showingFullPlayer = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingFullPlayer) {
            AudioPlayerView(player: player, accentColor: accentColor)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
@available(iOS 16.0, *)
struct AudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let player = AudioPlayer()

        Group {
            AudioPlayerView(player: player)
                .frame(height: 600)
                .previewDisplayName("Full Player")

            CompactAudioPlayerView(player: player)
                .previewDisplayName("Compact Player")
        }
        .preferredColorScheme(.dark)
    }
}
#endif
