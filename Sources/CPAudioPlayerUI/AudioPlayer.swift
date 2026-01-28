//
//  AudioPlayer.swift
//  CPAudioPlayer
//
//  Swift wrapper for CPAudioPlayer
//

import Foundation
import Combine
import UniformTypeIdentifiers
import CPAudioPlayer
import AVFoundation
import SwiftUI

// MARK: - Repeat Mode

/// Repeat mode options for playback
public enum RepeatMode: String, CaseIterable {
    case off = "Off"
    case one = "Repeat One"
    case all = "Repeat All"

    public var iconName: String {
        switch self {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
}

/// Swift wrapper for CPAudioPlayer providing a modern Swift interface
@objcMembers
public class AudioPlayer: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var trackTitle: String = ""
    @Published public private(set) var artistName: String = ""
    @Published public private(set) var currentFileURL: URL?

    /// Error message when file import fails
    @Published public var importError: String?

    // EQ bands
    @Published public var eqBands: [Float] = Array(repeating: 0, count: 7)

    // Effects
    @Published public var bassBoost: Float = 0 {
        didSet {
            player?.setbassBoost(bassBoost)
        }
    }

    @Published public var treble: Float = 0 {
        didSet {
            player?.setTreble(treble)
        }
    }

    @Published public var reverb: Float = 0 {
        didSet {
            player?.setRoomSize(reverb)
        }
    }

    @Published public var balance: Float = 0 {
        didSet {
            player?.setChannelBalance(balance)
        }
    }

    // MARK: - Sleep Timer

    /// Whether sleep timer is active
    @Published public private(set) var sleepTimerActive: Bool = false

    /// Remaining time on sleep timer in seconds
    @Published public private(set) var sleepTimerRemaining: TimeInterval = 0

    /// Total sleep timer duration that was set
    @Published public private(set) var sleepTimerDuration: TimeInterval = 0

    // MARK: - Repeat Mode

    /// Repeat mode for playback
    @Published public var repeatMode: RepeatMode = .off

    // MARK: - Audio Info

    /// Current audio file format (e.g., "MP3", "AAC")
    @Published public private(set) var audioFormat: String = ""

    /// Audio file size in bytes
    @Published public private(set) var fileSize: Int64 = 0

    // MARK: - Custom Presets

    /// User's custom saved presets
    @Published public private(set) var customPresets: [String: [Float]] = [:]

    // MARK: - Private Properties

    private var player: CPAudioPlayer?
    private var playbackTimer: Timer?
    private var sleepTimer: Timer?
    private var fadeTimer: Timer?
    private var originalVolume: Float = 1.0
    private static let customPresetsKey = "CPAudioPlayer.customPresets"

    /// Default EQ frequencies in Hz
    public static let defaultFrequencies: [Float] = [60, 150, 400, 1100, 3100, 8000, 16000]

    /// Supported audio file types for import
    public static let supportedTypes: [UTType] = [
        .mp3,
        .mpeg4Audio,
        .wav,
        .aiff,
        .audio,
        UTType(filenameExtension: "flac") ?? .audio,
        UTType(filenameExtension: "ogg") ?? .audio,
        UTType(filenameExtension: "wma") ?? .audio,
        UTType(filenameExtension: "alac") ?? .audio,
        UTType(filenameExtension: "aac") ?? .audio,
        UTType(filenameExtension: "caf") ?? .audio
    ]

    /// The library manager for persistent song storage
    @Published public private(set) var libraryManager = LibraryManager()

    /// Currently playing song metadata
    @Published public private(set) var currentSong: SongMetadata?

    /// Available EQ presets
    public static let presets: [String: [Float]] = [
        "Flat": [0, 0, 0, 0, 0, 0, 0],
        "Bass Boost": [6, 4, 2, 0, 0, 0, 0],
        "Treble Boost": [0, 0, 0, 0, 2, 4, 6],
        "Rock": [4, 2, -1, 0, 2, 4, 5],
        "Pop": [-1, 1, 3, 4, 3, 1, -1],
        "Jazz": [3, 1, -2, 0, 2, 4, 5],
        "Classical": [4, 3, 0, 0, 0, 2, 4],
        "Electronic": [5, 4, 0, -2, 0, 4, 5],
        "Hip Hop": [5, 4, 1, 0, -1, 2, 3],
        "Acoustic": [4, 2, 0, 1, 2, 3, 3],
        "Vocal": [-2, 0, 2, 4, 3, 1, 0],
        "Loudness": [5, 3, 0, 0, 0, 2, 4],
    ]

    // MARK: - Initialization

    public override init() {
        super.init()
        player = CPAudioPlayer()
        loadCustomPresets()
    }

    deinit {
        stopPlaybackTimer()
        cancelSleepTimer()
    }

    // MARK: - Audio File Loading

    /// Load an audio file from URL
    /// - Parameters:
    ///   - url: URL of the audio file
    ///   - title: Optional track title for display
    ///   - artist: Optional artist name for display
    /// - Returns: True if loading was successful
    @discardableResult
    public func load(url: URL, title: String? = nil, artist: String? = nil) -> Bool {
        var isError: DarwinBoolean = false
        player?.setupAudioFile(with: url, playBackDuration: 0, isError: &isError)

        if !isError.boolValue {
            duration = player?.playBackduration ?? 0
            trackTitle = title ?? url.deletingPathExtension().lastPathComponent
            artistName = artist ?? ""
            currentFileURL = url
            importError = nil
            syncFromPlayer()
            extractAudioInfo(from: url)

            // Update currentSong from library if available
            if let song = libraryManager.getSong(for: url) {
                currentSong = song
            }

            return true
        }
        return false
    }

    /// Load a song from library by metadata
    /// - Parameter song: The song metadata
    /// - Returns: True if loading was successful
    @discardableResult
    public func load(song: SongMetadata) -> Bool {
        guard let url = song.fileURL else {
            importError = "File not found"
            return false
        }

        currentSong = song
        return load(url: url, title: song.displayTitle, artist: song.displayArtist)
    }

    // MARK: - File Import

    /// Import an audio file from a security-scoped URL (e.g., from Files app)
    /// - Parameter url: The security-scoped URL from document picker
    /// - Returns: True if import was successful
    @discardableResult
    public func importFile(from url: URL) -> Bool {
        // Stop any current playback
        stop()
        importError = nil

        // Use LibraryManager for import
        if let metadata = libraryManager.importFile(from: url) {
            if let fileURL = metadata.fileURL {
                currentSong = metadata
                return load(url: fileURL, title: metadata.displayTitle, artist: metadata.displayArtist)
            }
        }

        importError = libraryManager.lastError ?? "Failed to import file"
        return false
    }

    /// Import multiple audio files
    /// - Parameter urls: Array of security-scoped URLs
    /// - Returns: Number of successfully imported files
    @discardableResult
    public func importFiles(from urls: [URL]) -> Int {
        let imported = libraryManager.importFiles(from: urls)

        // Load the first imported file if any
        if let first = imported.first, let fileURL = first.fileURL {
            currentSong = first
            load(url: fileURL, title: first.displayTitle, artist: first.displayArtist)
        }

        return imported.count
    }

    /// Copy a file to the app's documents directory
    /// - Parameter url: Source URL
    /// - Returns: URL of the copied file
    private func copyToDocuments(url: URL) throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let audioDirectory = documentsURL.appendingPathComponent("ImportedAudio", isDirectory: true)

        // Create audio directory if needed
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }

        let destinationURL = audioDirectory.appendingPathComponent(url.lastPathComponent)

        // Remove existing file if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // Copy the file
        try fileManager.copyItem(at: url, to: destinationURL)

        return destinationURL
    }

    /// Get list of previously imported audio files
    public func getImportedFiles() -> [URL] {
        let fileManager = FileManager.default
        guard let documentsURL = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return []
        }

        let audioDirectory = documentsURL.appendingPathComponent("ImportedAudio", isDirectory: true)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        // Filter for audio files and sort by creation date (newest first)
        return contents
            .filter { url in
                let ext = url.pathExtension.lowercased()
                return ["mp3", "m4a", "wav", "aiff", "aac", "caf"].contains(ext)
            }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
    }

    /// Delete an imported file
    /// - Parameter url: URL of the file to delete
    public func deleteImportedFile(at url: URL) throws {
        // Find the song in library and delete
        if let song = libraryManager.getSong(for: url) {
            if !libraryManager.deleteSong(id: song.id) {
                throw LibraryError.deleteFailed
            }
        } else {
            // Fallback: delete directly
            let fileManager = FileManager.default
            try fileManager.removeItem(at: url)
        }

        // If this was the current file, clear it
        if currentFileURL == url {
            stop()
            trackTitle = ""
            artistName = ""
            duration = 0
            currentFileURL = nil
            currentSong = nil
        }
    }

    /// Delete a song by ID
    /// - Parameter id: The song ID
    /// - Returns: True if deletion was successful
    @discardableResult
    public func deleteSong(id: UUID) -> Bool {
        let song = libraryManager.getSong(id: id)
        let wasCurrentSong = currentSong?.id == id

        if libraryManager.deleteSong(id: id) {
            if wasCurrentSong {
                stop()
                trackTitle = ""
                artistName = ""
                duration = 0
                currentFileURL = nil
                currentSong = nil
            }
            return true
        }
        return false
    }

    // MARK: - Playback Control

    /// Start or resume playback
    @discardableResult
    public func play() -> Bool {
        let success = player?.play() ?? false
        if success {
            isPlaying = true
            startPlaybackTimer()
        }
        return success
    }

    /// Pause playback
    public func pause() {
        player?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }

    /// Stop playback and reset to beginning
    public func stop() {
        player?.stop()
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
    }

    /// Toggle between play and pause
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Seek to a specific time
    /// - Parameter time: Time in seconds
    public func seek(to time: Double) {
        player?.setPlayBackTime(time)
        currentTime = time
    }

    /// Seek to a percentage of the track
    /// - Parameter percentage: Value between 0 and 1
    public func seek(toPercentage percentage: Double) {
        let time = percentage * duration
        seek(to: time)
    }

    // MARK: - EQ Control

    /// Set value for a specific EQ band
    /// - Parameters:
    ///   - value: Gain in dB (typically -12 to +12)
    ///   - band: Band index (0-6 for 7-band EQ)
    public func setEQ(value: Float, forBand band: Int) {
        guard band >= 0 && band < eqBands.count else { return }
        eqBands[band] = value
        applyEQToPlayer()
    }

    /// Set all EQ band values at once
    /// - Parameter values: Array of gain values in dB
    public func setEQBands(_ values: [Float]) {
        for i in 0..<min(values.count, eqBands.count) {
            eqBands[i] = values[i]
        }
        applyEQToPlayer()
    }

    /// Apply a preset by name
    /// - Parameter name: Preset name from available presets
    public func applyPreset(_ name: String) {
        guard let values = Self.presets[name] else { return }
        setEQBands(values)
    }

    /// Reset all EQ bands to 0 dB
    public func resetEQ() {
        eqBands = Array(repeating: 0, count: 7)
        applyEQToPlayer()
    }

    /// Reset all effects to default values
    public func resetAllEffects() {
        resetEQ()
        bassBoost = 0
        treble = 0
        reverb = 0
        balance = 0
    }

    // MARK: - Private Methods

    private func applyEQToPlayer() {
        let nsArray = eqBands.map { NSNumber(value: $0) }
        player?.setBandValue(nsArray)
    }

    private func syncFromPlayer() {
        guard let player = player else { return }

        bassBoost = player.getBassBoost()
        treble = player.getTreble()
        reverb = player.getRommSize()
        balance = player.getChannelBalance()

        for i in 0..<eqBands.count {
            eqBands[i] = player.getValue(forBand: i)
        }
    }

    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentPlaybackTime

            if self.currentTime >= self.duration && self.duration > 0 {
                self.handleTrackEnd()
            }
        }
    }

    private func handleTrackEnd() {
        switch repeatMode {
        case .off:
            stop()
        case .one:
            seek(to: 0)
            play()
        case .all:
            // In single track mode, repeat all behaves like repeat one
            seek(to: 0)
            play()
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    /// Set completion handler for when song finishes
    /// - Parameter completion: Handler called when playback completes
    public func onCompletion(_ completion: @escaping () -> Void) {
        player?.handleSongPlayingCompletion(completion)
    }

    // MARK: - Sleep Timer

    /// Start the sleep timer with optional fade out
    /// - Parameters:
    ///   - duration: Time in seconds until playback stops
    ///   - fadeOut: Whether to gradually fade volume before stopping (last 30 seconds)
    public func startSleepTimer(duration: TimeInterval, fadeOut: Bool = true) {
        cancelSleepTimer()

        sleepTimerDuration = duration
        sleepTimerRemaining = duration
        sleepTimerActive = true
        originalVolume = player?.getVolume() ?? 1.0

        // Update remaining time every second
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.sleepTimerRemaining -= 1

            // Start fade out in last 30 seconds
            if fadeOut && self.sleepTimerRemaining <= 30 && self.sleepTimerRemaining > 0 {
                let fadeProgress = Float(self.sleepTimerRemaining) / 30.0
                self.player?.setVolume(self.originalVolume * fadeProgress)
            }

            if self.sleepTimerRemaining <= 0 {
                self.executeSleepTimerEnd()
            }
        }
    }

    /// Cancel the sleep timer
    public func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        fadeTimer?.invalidate()
        fadeTimer = nil
        sleepTimerActive = false
        sleepTimerRemaining = 0
        sleepTimerDuration = 0

        // Restore original volume
        if originalVolume > 0 {
            player?.setVolume(originalVolume)
        }
    }

    /// Formatted sleep timer remaining string (m:ss)
    public var sleepTimerRemainingFormatted: String {
        let mins = Int(sleepTimerRemaining) / 60
        let secs = Int(sleepTimerRemaining) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func executeSleepTimerEnd() {
        pause()
        cancelSleepTimer()
        player?.setVolume(originalVolume)
    }

    // MARK: - Custom Presets

    /// Save current EQ settings as a custom preset
    /// - Parameter name: Name for the preset
    public func saveCustomPreset(name: String) {
        var presets = customPresets
        presets[name] = eqBands
        customPresets = presets
        persistCustomPresets()
    }

    /// Delete a custom preset
    /// - Parameter name: Name of the preset to delete
    public func deleteCustomPreset(name: String) {
        var presets = customPresets
        presets.removeValue(forKey: name)
        customPresets = presets
        persistCustomPresets()
    }

    /// Apply a custom preset by name
    /// - Parameter name: Name of the custom preset
    /// - Returns: True if preset was found and applied
    @discardableResult
    public func applyCustomPreset(_ name: String) -> Bool {
        guard let values = customPresets[name] else { return false }
        setEQBands(values)
        return true
    }

    /// Get all presets (built-in + custom)
    public var allPresets: [String: [Float]] {
        var all = Self.presets
        for (name, values) in customPresets {
            all[name] = values
        }
        return all
    }

    private func loadCustomPresets() {
        if let data = UserDefaults.standard.data(forKey: Self.customPresetsKey),
           let presets = try? JSONDecoder().decode([String: [Float]].self, from: data) {
            customPresets = presets
        }
    }

    private func persistCustomPresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: Self.customPresetsKey)
        }
    }

    // MARK: - Audio Info

    private func extractAudioInfo(from url: URL) {
        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            fileSize = size
        } else {
            fileSize = 0
        }

        // Get audio format from file extension and AVAsset
        let ext = url.pathExtension.uppercased()
        audioFormat = ext

        // Try to get more detailed format info from AVAsset
        let asset = AVAsset(url: url)
        if let track = asset.tracks(withMediaType: .audio).first {
            let formatDescriptions = track.formatDescriptions as? [CMFormatDescription]
            if let formatDesc = formatDescriptions?.first {
                let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
                if let asbd = audioStreamBasicDescription?.pointee {
                    let sampleRate = Int(asbd.mSampleRate)
                    let channels = asbd.mChannelsPerFrame
                    audioFormat = "\(ext) • \(sampleRate / 1000)kHz • \(channels == 1 ? "Mono" : "Stereo")"
                }
            }
        }
    }

    /// Formatted file size string (e.g., "3.5 MB")
    public var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Bitrate in kbps (approximate)
    public var bitrate: Int {
        guard duration > 0 && fileSize > 0 else { return 0 }
        return Int((Double(fileSize) * 8) / duration / 1000)
    }

    /// Formatted bitrate string (e.g., "320 kbps")
    public var bitrateFormatted: String {
        "\(bitrate) kbps"
    }
}

// MARK: - Convenience Extensions

public extension AudioPlayer {
    /// Current playback progress as a percentage (0-1)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    /// Formatted current time string (m:ss)
    var currentTimeFormatted: String {
        formatTime(currentTime)
    }

    /// Formatted duration string (m:ss)
    var durationFormatted: String {
        formatTime(duration)
    }

    /// Formatted remaining time string (-m:ss)
    var remainingTimeFormatted: String {
        "-" + formatTime(duration - currentTime)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
