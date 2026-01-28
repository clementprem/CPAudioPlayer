//
//  SwiftUIExample.swift
//  CPAudioPlayer
//
//  Example demonstrating SwiftUI integration
//

import SwiftUI

// MARK: - SwiftUI Example View

/// Example SwiftUI view demonstrating how to use AudioPlayerView
/// To use this in your app:
/// 1. Import the CPAudioPlayer module
/// 2. Create an AudioPlayer instance as a @StateObject
/// 3. Add the AudioPlayerView to your view hierarchy
///
/// Example usage in SwiftUI App:
/// ```swift
/// import SwiftUI
/// import CPAudioPlayerUI
///
/// @main
/// struct MyMusicApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///         }
///     }
/// }
///
/// struct ContentView: View {
///     @StateObject private var player = AudioPlayer()
///
///     var body: some View {
///         VStack {
///             AudioPlayerView(player: player)
///                 .frame(height: 500)
///                 .padding()
///         }
///         .background(Color.black)
///         .onAppear {
///             // Load your audio file
///             if let url = Bundle.main.url(forResource: "song", withExtension: "mp3") {
///                 player.load(url: url, title: "My Song", artist: "Artist Name")
///             }
///         }
///     }
/// }
/// ```

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 16.0, *)
struct SwiftUIExampleView: View {
    @StateObject private var player = AudioPlayer()
    @State private var showingFilePicker = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Full Audio Player View
                    AudioPlayerView(
                        player: player,
                        accentColor: Color(red: 0, green: 0.8, blue: 0.8),
                        showsTransportControls: true,
                        showsTimeSlider: true,
                        showsEqualizer: true,
                        showsEffects: true,
                        showsPresets: true
                    )
                    .frame(minHeight: 500)

                    Divider()
                        .background(Color.gray)

                    // Compact Player (alternative)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compact Mode")
                            .font(.headline)
                            .foregroundColor(.white)

                        CompactAudioPlayerView(
                            player: player,
                            accentColor: Color(red: 0, green: 0.8, blue: 0.8)
                        )
                    }
                    .padding()
                }
                .padding()
            }
            .background(Color(white: 0.1).ignoresSafeArea())
            .navigationTitle("Audio Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Load") {
                        loadSampleAudio()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadSampleAudio() {
        // Try to load a sample audio file from the bundle
        if let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") {
            player.load(url: url, title: "Sample Track", artist: "Demo Artist")
        } else {
            // Set demo values for UI preview
            player.load(
                url: URL(fileURLWithPath: "/path/to/audio.mp3"),
                title: "Demo Track",
                artist: "Demo Artist"
            )
        }
    }
}

// MARK: - Minimal Example

@available(iOS 16.0, *)
struct MinimalExampleView: View {
    @StateObject private var player = AudioPlayer()

    var body: some View {
        VStack {
            // Just the EQ, no transport controls
            AudioPlayerView(
                player: player,
                showsTransportControls: false,
                showsTimeSlider: false,
                showsEqualizer: true,
                showsEffects: true
            )
        }
        .background(Color(white: 0.1))
    }
}

// MARK: - Programmatic Control Example

@available(iOS 16.0, *)
struct ProgrammaticExampleView: View {
    @StateObject private var player = AudioPlayer()

    var body: some View {
        VStack(spacing: 20) {
            // Custom controls
            HStack(spacing: 20) {
                Button("Bass +") {
                    player.bassBoost = min(10, player.bassBoost + 1)
                }

                Button("Preset: Rock") {
                    player.applyPreset("Rock")
                }

                Button("Reset") {
                    player.resetAllEffects()
                }
            }
            .buttonStyle(.borderedProminent)

            // Display current values
            VStack(alignment: .leading) {
                Text("Bass: \(player.bassBoost, specifier: "%.1f")")
                Text("Treble: \(player.treble, specifier: "%.1f")")
                Text("Reverb: \(Int(player.reverb * 100))%")
                Text("EQ: \(player.eqBands.map { String(format: "%.0f", $0) }.joined(separator: ", "))")
                Text("Repeat: \(player.repeatMode.rawValue)")
                if player.sleepTimerActive {
                    Text("Sleep: \(player.sleepTimerRemainingFormatted)")
                }
            }
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.white)
            .padding()
            .background(Color(white: 0.15))
            .cornerRadius(8)

            // Feature controls
            HStack(spacing: 16) {
                Button("Sleep 5m") {
                    player.startSleepTimer(duration: 5 * 60)
                }

                Button("Save Preset") {
                    player.saveCustomPreset(name: "My Custom")
                }

                Button("Repeat") {
                    switch player.repeatMode {
                    case .off: player.repeatMode = .one
                    case .one: player.repeatMode = .all
                    case .all: player.repeatMode = .off
                    }
                }
            }
            .buttonStyle(.bordered)

            AudioPlayerView(player: player)
        }
        .padding()
        .background(Color(white: 0.1))
    }
}

// MARK: - Preview Provider

#if DEBUG
@available(iOS 16.0, *)
struct SwiftUIExampleView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SwiftUIExampleView()
                .previewDisplayName("Full Example")

            MinimalExampleView()
                .previewDisplayName("Minimal")

            ProgrammaticExampleView()
                .previewDisplayName("Programmatic")
        }
    }
}
#endif
#endif
