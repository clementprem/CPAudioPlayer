//
//  AudioPlayerView.swift
//  CPAudioPlayer
//
//  SwiftUI view for audio player with EQ and controls
//

import SwiftUI
import UniformTypeIdentifiers

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
    public var showsFileImport: Bool
    public var compactMode: Bool

    @State private var showingPresetPicker = false
    @State private var showingFilePicker = false
    @State private var showingLibrary = false
    @State private var showingErrorAlert = false

    public init(
        player: AudioPlayer,
        accentColor: Color = Color(red: 0, green: 0.8, blue: 0.8),
        showsTransportControls: Bool = true,
        showsTimeSlider: Bool = true,
        showsEqualizer: Bool = true,
        showsEffects: Bool = true,
        showsPresets: Bool = true,
        showsFileImport: Bool = true,
        compactMode: Bool = false
    ) {
        self.player = player
        self.accentColor = accentColor
        self.showsTransportControls = showsTransportControls
        self.showsTimeSlider = showsTimeSlider
        self.showsEqualizer = showsEqualizer
        self.showsEffects = showsEffects
        self.showsPresets = showsPresets
        self.showsFileImport = showsFileImport
        self.compactMode = compactMode
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Track Info with Import Button
                TrackInfoSection(
                    player: player,
                    accentColor: accentColor,
                    showsFileImport: showsFileImport,
                    showingFilePicker: $showingFilePicker,
                    showingLibrary: $showingLibrary
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
        .sheet(isPresented: $showingLibrary) {
            LibraryView(player: player, accentColor: accentColor)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: AudioPlayer.supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if !player.importFile(from: url) {
                        showingErrorAlert = true
                    }
                }
            case .failure(let error):
                player.importError = error.localizedDescription
                showingErrorAlert = true
            }
        }
        .alert("Import Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {
                player.importError = nil
            }
        } message: {
            Text(player.importError ?? "Unknown error occurred")
        }
    }
}

// MARK: - Track Info Section

@available(iOS 16.0, *)
struct TrackInfoSection: View {
    @ObservedObject var player: AudioPlayer
    let accentColor: Color
    let showsFileImport: Bool
    @Binding var showingFilePicker: Bool
    @Binding var showingLibrary: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Track info
            VStack(spacing: 4) {
                Text(player.trackTitle.isEmpty ? "No Track Selected" : player.trackTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if !player.artistName.isEmpty {
                    Text(player.artistName)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                // Audio info
                if !player.audioFormat.isEmpty {
                    HStack(spacing: 8) {
                        Text(player.audioFormat)
                        if player.bitrate > 0 {
                            Text("•")
                            Text(player.bitrateFormatted)
                        }
                        if player.fileSize > 0 {
                            Text("•")
                            Text(player.fileSizeFormatted)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
                }
            }

            // Import buttons
            if showsFileImport {
                HStack(spacing: 16) {
                    Button(action: { showingFilePicker = true }) {
                        Label("Add from Files", systemImage: "folder")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColor)

                    Button(action: { showingLibrary = true }) {
                        Label("Library", systemImage: "music.note.list")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
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
    @State private var showingSleepTimer = false

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
            HStack(spacing: 24) {
                // Repeat mode button
                Button(action: {
                    switch player.repeatMode {
                    case .off:
                        player.repeatMode = .one
                    case .one:
                        player.repeatMode = .all
                    case .all:
                        player.repeatMode = .off
                    }
                }) {
                    Image(systemName: player.repeatMode.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(player.repeatMode == .off ? .gray : accentColor)
                        .overlay(
                            player.repeatMode == .all ?
                            Circle()
                                .fill(accentColor)
                                .frame(width: 6, height: 6)
                                .offset(x: 8, y: -8) : nil
                        )
                }
                .frame(width: 44, height: 44)

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

                // Sleep timer button
                Button(action: { showingSleepTimer = true }) {
                    ZStack {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 20))
                            .foregroundColor(player.sleepTimerActive ? accentColor : .gray)

                        if player.sleepTimerActive {
                            Text(player.sleepTimerRemainingFormatted)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(accentColor)
                                .offset(y: 16)
                        }
                    }
                }
                .frame(width: 44, height: 44)
            }
        }
        .sheet(isPresented: $showingSleepTimer) {
            SleepTimerView(player: player, accentColor: accentColor)
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

    @State private var showingSavePreset = false
    @State private var newPresetName = ""
    @State private var presetToDelete: String?
    @State private var showingDeleteConfirmation = false

    private var builtInPresetNames: [String] {
        AudioPlayer.presets.keys.sorted()
    }

    private var customPresetNames: [String] {
        player.customPresets.keys.sorted()
    }

    var body: some View {
        NavigationView {
            List {
                // Built-in presets
                Section("Built-in Presets") {
                    ForEach(builtInPresetNames, id: \.self) { preset in
                        Button(action: {
                            player.applyPreset(preset)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text(preset)
                                .foregroundColor(.primary)
                        }
                    }
                }

                // Custom presets
                if !customPresetNames.isEmpty {
                    Section("My Presets") {
                        ForEach(customPresetNames, id: \.self) { preset in
                            Button(action: {
                                player.applyCustomPreset(preset)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Text(preset)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(accentColor)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    presetToDelete = preset
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Save current as preset
                Section {
                    Button(action: { showingSavePreset = true }) {
                        Label("Save Current as Preset", systemImage: "plus.circle")
                            .foregroundColor(accentColor)
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
            .alert("Save Preset", isPresented: $showingSavePreset) {
                TextField("Preset Name", text: $newPresetName)
                Button("Cancel", role: .cancel) {
                    newPresetName = ""
                }
                Button("Save") {
                    if !newPresetName.isEmpty {
                        player.saveCustomPreset(name: newPresetName)
                        newPresetName = ""
                    }
                }
            } message: {
                Text("Enter a name for your custom preset")
            }
            .confirmationDialog(
                "Delete Preset?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let name = presetToDelete {
                        player.deleteCustomPreset(name: name)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let name = presetToDelete {
                    Text("'\(name)' will be permanently deleted.")
                }
            }
        }
    }
}

// MARK: - Sleep Timer View

@available(iOS 16.0, *)
struct SleepTimerView: View {
    @ObservedObject var player: AudioPlayer
    let accentColor: Color
    @Environment(\.dismiss) var dismiss

    private let timerOptions: [(String, TimeInterval)] = [
        ("5 minutes", 5 * 60),
        ("10 minutes", 10 * 60),
        ("15 minutes", 15 * 60),
        ("30 minutes", 30 * 60),
        ("45 minutes", 45 * 60),
        ("1 hour", 60 * 60),
        ("1.5 hours", 90 * 60),
        ("2 hours", 120 * 60)
    ]

    var body: some View {
        NavigationView {
            List {
                if player.sleepTimerActive {
                    Section {
                        VStack(spacing: 12) {
                            Text("Sleep Timer Active")
                                .font(.headline)
                                .foregroundColor(accentColor)

                            Text(player.sleepTimerRemainingFormatted)
                                .font(.system(size: 48, weight: .light, design: .monospaced))
                                .foregroundColor(.primary)

                            Text("Music will fade out and stop")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                player.cancelSleepTimer()
                            }) {
                                Text("Cancel Timer")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Section("Set Sleep Timer") {
                        ForEach(timerOptions, id: \.1) { option in
                            Button(action: {
                                player.startSleepTimer(duration: option.1)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "moon.zzz")
                                        .foregroundColor(accentColor)
                                        .frame(width: 24)
                                    Text(option.0)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }

                    Section {
                        Text("The music will gradually fade out during the last 30 seconds before stopping.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
    }
}

// MARK: - Library View

@available(iOS 16.0, *)
struct LibraryView: View {
    @ObservedObject var player: AudioPlayer
    let accentColor: Color
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var sortOption: LibraryManager.SortOption = .dateAdded
    @State private var sortAscending = false
    @State private var showingFilePicker = false
    @State private var showingDeleteConfirmation = false
    @State private var songToDelete: SongMetadata?
    @State private var songToEdit: SongMetadata?
    @State private var showingEditSheet = false
    @State private var showingSortMenu = false
    @State private var selectedSongs: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingBatchDeleteConfirmation = false

    private var songs: [SongMetadata] {
        let sorted = player.libraryManager.getSortedSongs(by: sortOption, ascending: sortAscending)
        if searchText.isEmpty {
            return sorted
        }
        return player.libraryManager.searchSongs(query: searchText)
    }

    var body: some View {
        NavigationView {
            Group {
                if player.libraryManager.songs.isEmpty {
                    EmptyLibraryView(
                        accentColor: accentColor,
                        showingFilePicker: $showingFilePicker
                    )
                } else {
                    VStack(spacing: 0) {
                        // Library stats header
                        LibraryStatsHeader(
                            songCount: player.libraryManager.songCount,
                            totalDuration: player.libraryManager.totalDurationFormatted,
                            totalSize: player.libraryManager.totalFileSizeFormatted,
                            accentColor: accentColor
                        )

                        // Song list
                        List(selection: isSelectionMode ? $selectedSongs : nil) {
                            ForEach(songs) { song in
                                SongRowView(
                                    song: song,
                                    isPlaying: player.currentSong?.id == song.id,
                                    accentColor: accentColor,
                                    onTap: {
                                        if !isSelectionMode {
                                            player.load(song: song)
                                            dismiss()
                                        }
                                    },
                                    onEdit: {
                                        songToEdit = song
                                        showingEditSheet = true
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        songToDelete = song
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        songToEdit = song
                                        showingEditSheet = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                                .tag(song.id)
                            }
                        }
                        .listStyle(.plain)
                        .searchable(text: $searchText, prompt: "Search songs")

                        // Selection mode toolbar
                        if isSelectionMode && !selectedSongs.isEmpty {
                            SelectionToolbar(
                                selectedCount: selectedSongs.count,
                                accentColor: accentColor,
                                onDelete: {
                                    showingBatchDeleteConfirmation = true
                                },
                                onCancel: {
                                    selectedSongs.removeAll()
                                    isSelectionMode = false
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !player.libraryManager.songs.isEmpty {
                        Button(isSelectionMode ? "Cancel" : "Select") {
                            if isSelectionMode {
                                selectedSongs.removeAll()
                            }
                            isSelectionMode.toggle()
                        }
                        .foregroundColor(accentColor)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !player.libraryManager.songs.isEmpty {
                            Menu {
                                ForEach(LibraryManager.SortOption.allCases, id: \.self) { option in
                                    Button {
                                        if sortOption == option {
                                            sortAscending.toggle()
                                        } else {
                                            sortOption = option
                                            sortAscending = true
                                        }
                                    } label: {
                                        HStack {
                                            Text(option.rawValue)
                                            if sortOption == option {
                                                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundColor(accentColor)
                            }

                            Button {
                                showingFilePicker = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .foregroundColor(accentColor)
                        }

                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(accentColor)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: AudioPlayer.supportedTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    _ = player.importFiles(from: urls)
                case .failure(let error):
                    player.importError = error.localizedDescription
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let song = songToEdit {
                    SongEditView(
                        song: song,
                        libraryManager: player.libraryManager,
                        accentColor: accentColor
                    )
                }
            }
            .confirmationDialog(
                "Delete this song?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let song = songToDelete {
                        player.deleteSong(id: song.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let song = songToDelete {
                    Text("'\(song.displayTitle)' will be permanently removed from your library.")
                }
            }
            .confirmationDialog(
                "Delete \(selectedSongs.count) songs?",
                isPresented: $showingBatchDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    _ = player.libraryManager.deleteSongs(ids: selectedSongs)
                    selectedSongs.removeAll()
                    isSelectionMode = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("These songs will be permanently removed from your library.")
            }
        }
    }
}

// MARK: - Empty Library View

@available(iOS 16.0, *)
struct EmptyLibraryView: View {
    let accentColor: Color
    @Binding var showingFilePicker: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.house")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("Your Library is Empty")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Add songs from the Files app to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showingFilePicker = true }) {
                Label("Add from Files", systemImage: "folder.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(accentColor)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Library Stats Header

@available(iOS 16.0, *)
struct LibraryStatsHeader: View {
    let songCount: Int
    let totalDuration: String
    let totalSize: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 16) {
            StatBadge(icon: "music.note", value: "\(songCount)", label: "songs")
            StatBadge(icon: "clock", value: totalDuration, label: "total")
            StatBadge(icon: "internaldrive", value: totalSize, label: "size")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(white: 0.08))
    }
}

@available(iOS 16.0, *)
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Song Row View

@available(iOS 16.0, *)
struct SongRowView: View {
    let song: SongMetadata
    let isPlaying: Bool
    let accentColor: Color
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Album art placeholder / format icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(isPlaying ? accentColor : .gray)
                }

                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.displayTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isPlaying ? accentColor : .primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(song.displayArtist)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if !song.album.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Text(song.album)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 8) {
                        // Format badge
                        Text(song.fileExtension.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(formatColor(for: song.fileExtension))
                            .cornerRadius(4)

                        // Duration
                        Text(song.durationFormatted)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        // File size
                        Text(song.fileSizeFormatted)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Playing indicator
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func formatColor(for ext: String) -> Color {
        switch ext.lowercased() {
        case "mp3":
            return .blue
        case "m4a", "aac", "alac":
            return .purple
        case "wav", "aiff":
            return .green
        case "flac":
            return .orange
        case "ogg":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Selection Toolbar

@available(iOS 16.0, *)
struct SelectionToolbar: View {
    let selectedCount: Int
    let accentColor: Color
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack {
            Text("\(selectedCount) selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(white: 0.15))
    }
}

// MARK: - Song Edit View

@available(iOS 16.0, *)
struct SongEditView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var libraryManager: LibraryManager

    let song: SongMetadata
    let accentColor: Color

    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var genre: String
    @State private var year: String
    @State private var comments: String
    @State private var showingRename = false
    @State private var newFileName: String
    @State private var showingError = false
    @State private var errorMessage = ""

    init(song: SongMetadata, libraryManager: LibraryManager, accentColor: Color) {
        self.song = song
        self.libraryManager = libraryManager
        self.accentColor = accentColor

        _title = State(initialValue: song.title)
        _artist = State(initialValue: song.artist)
        _album = State(initialValue: song.album)
        _genre = State(initialValue: song.genre)
        _year = State(initialValue: song.year)
        _comments = State(initialValue: song.comments)
        _newFileName = State(initialValue: (song.fileName as NSString).deletingPathExtension)
    }

    var body: some View {
        NavigationView {
            Form {
                // File info section
                Section("File Information") {
                    HStack {
                        Text("File Name")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(song.fileName)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    HStack {
                        Text("Format")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(song.formatDescription)
                            .foregroundColor(.primary)
                    }

                    HStack {
                        Text("Duration")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(song.durationFormatted)
                            .foregroundColor(.primary)
                    }

                    HStack {
                        Text("Size")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(song.fileSizeFormatted)
                            .foregroundColor(.primary)
                    }

                    if song.bitrate > 0 {
                        HStack {
                            Text("Bitrate")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(song.bitrateFormatted)
                                .foregroundColor(.primary)
                        }
                    }

                    Button {
                        showingRename = true
                    } label: {
                        Label("Rename File", systemImage: "pencil")
                            .foregroundColor(accentColor)
                    }
                }

                // Metadata section
                Section("Metadata") {
                    TextField("Title", text: $title)
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Genre", text: $genre)
                    TextField("Year", text: $year)
                        .keyboardType(.numberPad)
                }

                // Comments section
                Section("Comments") {
                    TextEditor(text: $comments)
                        .frame(minHeight: 80)
                }

                // Dates section
                Section("History") {
                    HStack {
                        Text("Added")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(song.dateAdded, style: .date)
                            .foregroundColor(.primary)
                    }

                    HStack {
                        Text("Modified")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(song.dateModified, style: .date)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Edit Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                    .fontWeight(.semibold)
                }
            }
            .alert("Rename File", isPresented: $showingRename) {
                TextField("File name", text: $newFileName)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    if !libraryManager.renameFile(for: song.id, to: newFileName) {
                        errorMessage = libraryManager.lastError ?? "Failed to rename file"
                        showingError = true
                    }
                }
            } message: {
                Text("Enter a new name for the file")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveChanges() {
        libraryManager.updateMetadata(
            for: song.id,
            title: title,
            artist: artist,
            album: album,
            genre: genre,
            year: year,
            comments: comments
        )
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
