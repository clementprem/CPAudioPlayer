//
//  AudioPlayer.swift
//  CPAudioPlayer
//
//  Swift wrapper for CPAudioPlayer
//

import Foundation
import Combine
import CPAudioPlayer

/// Swift wrapper for CPAudioPlayer providing a modern Swift interface
@objcMembers
public class AudioPlayer: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var trackTitle: String = ""
    @Published public private(set) var artistName: String = ""

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

    // MARK: - Private Properties

    private var player: CPAudioPlayer?
    private var playbackTimer: Timer?

    /// Default EQ frequencies in Hz
    public static let defaultFrequencies: [Float] = [60, 150, 400, 1100, 3100, 8000, 16000]

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
    }

    deinit {
        stopPlaybackTimer()
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
            trackTitle = title ?? url.lastPathComponent
            artistName = artist ?? ""
            syncFromPlayer()
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
                self.stop()
            }
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
