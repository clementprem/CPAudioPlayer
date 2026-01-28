//
//  LibraryManager.swift
//  CPAudioPlayer
//
//  Library management for audio files with metadata persistence
//

import Foundation
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Song Metadata Model

/// Represents metadata for an audio file in the library
public struct SongMetadata: Codable, Identifiable, Equatable {
    public let id: UUID
    public var fileName: String
    public var title: String
    public var artist: String
    public var album: String
    public var genre: String
    public var year: String
    public var comments: String
    public let fileExtension: String
    public let fileSize: Int64
    public let duration: TimeInterval
    public let dateAdded: Date
    public var dateModified: Date
    public let sampleRate: Int
    public let channels: Int
    public let bitrate: Int

    /// The actual file URL in the documents directory
    public var fileURL: URL? {
        LibraryManager.getAudioDirectory()?.appendingPathComponent(fileName)
    }

    /// Display title (uses title if available, otherwise filename without extension)
    public var displayTitle: String {
        if !title.isEmpty {
            return title
        }
        return (fileName as NSString).deletingPathExtension
    }

    /// Display artist (uses artist if available, otherwise "Unknown Artist")
    public var displayArtist: String {
        artist.isEmpty ? "Unknown Artist" : artist
    }

    /// Formatted duration string (m:ss)
    public var durationFormatted: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Formatted file size string
    public var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Formatted bitrate string
    public var bitrateFormatted: String {
        "\(bitrate) kbps"
    }

    /// Audio format description
    public var formatDescription: String {
        var parts: [String] = [fileExtension.uppercased()]
        if sampleRate > 0 {
            parts.append("\(sampleRate / 1000)kHz")
        }
        parts.append(channels == 1 ? "Mono" : "Stereo")
        return parts.joined(separator: " • ")
    }

    public init(
        id: UUID = UUID(),
        fileName: String,
        title: String = "",
        artist: String = "",
        album: String = "",
        genre: String = "",
        year: String = "",
        comments: String = "",
        fileExtension: String,
        fileSize: Int64 = 0,
        duration: TimeInterval = 0,
        dateAdded: Date = Date(),
        dateModified: Date = Date(),
        sampleRate: Int = 0,
        channels: Int = 2,
        bitrate: Int = 0
    ) {
        self.id = id
        self.fileName = fileName
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.year = year
        self.comments = comments
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.duration = duration
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitrate = bitrate
    }
}

// MARK: - Library Manager

/// Manages the audio file library with persistent metadata storage
public class LibraryManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var songs: [SongMetadata] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public var lastError: String?

    // MARK: - Private Properties

    private static let metadataFileName = "library_metadata.json"
    private static let audioDirectoryName = "ImportedAudio"

    /// Supported audio file extensions
    public static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "wav", "aiff", "aac", "caf", "flac", "ogg", "wma", "alac"
    ]

    /// Supported UTTypes for file picker
    public static let supportedUTTypes: [UTType] = [
        .mp3,
        .mpeg4Audio,
        .wav,
        .aiff,
        .audio,
        UTType(filenameExtension: "flac") ?? .audio,
        UTType(filenameExtension: "ogg") ?? .audio
    ].compactMap { $0 }

    // MARK: - Initialization

    public init() {
        loadLibrary()
    }

    // MARK: - Directory Management

    /// Get the audio files directory URL
    public static func getAudioDirectory() -> URL? {
        guard let documentsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        return documentsURL.appendingPathComponent(audioDirectoryName, isDirectory: true)
    }

    /// Get the metadata file URL
    private static func getMetadataFileURL() -> URL? {
        guard let documentsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        return documentsURL.appendingPathComponent(metadataFileName)
    }

    /// Ensure the audio directory exists
    private func ensureAudioDirectoryExists() throws {
        guard let audioDirectory = Self.getAudioDirectory() else {
            throw LibraryError.directoryNotFound
        }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Library Loading & Saving

    /// Load the library from persistent storage
    public func loadLibrary() {
        guard let metadataURL = Self.getMetadataFileURL() else {
            return
        }

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            // No metadata file yet, try to import existing files
            migrateExistingFiles()
            return
        }

        do {
            let data = try Data(contentsOf: metadataURL)
            songs = try JSONDecoder().decode([SongMetadata].self, from: data)

            // Verify files still exist and remove orphaned entries
            validateLibrary()
        } catch {
            lastError = "Failed to load library: \(error.localizedDescription)"
            migrateExistingFiles()
        }
    }

    /// Save the library to persistent storage
    private func saveLibrary() {
        guard let metadataURL = Self.getMetadataFileURL() else {
            return
        }

        do {
            let data = try JSONEncoder().encode(songs)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            lastError = "Failed to save library: \(error.localizedDescription)"
        }
    }

    /// Migrate existing audio files that don't have metadata
    private func migrateExistingFiles() {
        guard let audioDirectory = Self.getAudioDirectory() else {
            return
        }

        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        for url in contents {
            let ext = url.pathExtension.lowercased()
            guard Self.supportedExtensions.contains(ext) else { continue }

            // Check if we already have this file
            if songs.contains(where: { $0.fileName == url.lastPathComponent }) {
                continue
            }

            // Create metadata for existing file
            if let metadata = createMetadata(for: url) {
                songs.append(metadata)
            }
        }

        songs.sort { $0.dateAdded > $1.dateAdded }
        saveLibrary()
    }

    /// Validate that all library entries have corresponding files
    private func validateLibrary() {
        let validSongs = songs.filter { song in
            guard let url = song.fileURL else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }

        if validSongs.count != songs.count {
            songs = validSongs
            saveLibrary()
        }
    }

    // MARK: - File Import

    /// Import a file from a security-scoped URL (e.g., from Files app)
    /// - Parameter url: The security-scoped URL
    /// - Returns: The imported song metadata, or nil if import failed
    @discardableResult
    public func importFile(from url: URL) -> SongMetadata? {
        lastError = nil

        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            lastError = "Cannot access the selected file"
            return nil
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            try ensureAudioDirectoryExists()

            guard let audioDirectory = Self.getAudioDirectory() else {
                throw LibraryError.directoryNotFound
            }

            // Generate unique filename if needed
            let destinationURL = generateUniqueURL(for: url.lastPathComponent, in: audioDirectory)

            // Copy the file
            try FileManager.default.copyItem(at: url, to: destinationURL)

            // Create metadata
            guard var metadata = createMetadata(for: destinationURL) else {
                try? FileManager.default.removeItem(at: destinationURL)
                throw LibraryError.metadataExtractionFailed
            }

            // Extract embedded metadata if available
            extractEmbeddedMetadata(for: &metadata, from: destinationURL)

            // Add to library
            songs.insert(metadata, at: 0)
            saveLibrary()

            return metadata
        } catch {
            lastError = "Failed to import file: \(error.localizedDescription)"
            return nil
        }
    }

    /// Import multiple files
    /// - Parameter urls: Array of security-scoped URLs
    /// - Returns: Array of successfully imported song metadata
    public func importFiles(from urls: [URL]) -> [SongMetadata] {
        var imported: [SongMetadata] = []

        for url in urls {
            if let metadata = importFile(from: url) {
                imported.append(metadata)
            }
        }

        return imported
    }

    /// Generate a unique filename to avoid conflicts
    private func generateUniqueURL(for filename: String, in directory: URL) -> URL {
        let fileManager = FileManager.default
        var destinationURL = directory.appendingPathComponent(filename)

        if !fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        // File exists, generate unique name
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var counter = 1

        while fileManager.fileExists(atPath: destinationURL.path) {
            let newName = "\(name) (\(counter)).\(ext)"
            destinationURL = directory.appendingPathComponent(newName)
            counter += 1
        }

        return destinationURL
    }

    // MARK: - Metadata Extraction

    /// Create basic metadata for a file
    private func createMetadata(for url: URL) -> SongMetadata? {
        let fileManager = FileManager.default

        // Get file attributes
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }

        let creationDate = (attributes[.creationDate] as? Date) ?? Date()

        // Get audio properties
        let asset = AVAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)

        var sampleRate = 0
        var channels = 2
        var bitrate = 0

        if let track = asset.tracks(withMediaType: .audio).first {
            let formatDescriptions = track.formatDescriptions as? [CMFormatDescription]
            if let formatDesc = formatDescriptions?.first {
                if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
                    sampleRate = Int(asbd.mSampleRate)
                    channels = Int(asbd.mChannelsPerFrame)
                }
            }
        }

        // Calculate bitrate
        if duration > 0 && fileSize > 0 {
            bitrate = Int((Double(fileSize) * 8) / duration / 1000)
        }

        return SongMetadata(
            fileName: url.lastPathComponent,
            fileExtension: url.pathExtension.lowercased(),
            fileSize: fileSize,
            duration: duration,
            dateAdded: creationDate,
            dateModified: Date(),
            sampleRate: sampleRate,
            channels: channels,
            bitrate: bitrate
        )
    }

    /// Extract embedded metadata (ID3 tags, etc.) from audio file
    private func extractEmbeddedMetadata(for metadata: inout SongMetadata, from url: URL) {
        let asset = AVAsset(url: url)

        // Common metadata keys
        let commonKeys: [(AVMetadataKey, WritableKeyPath<SongMetadata, String>)] = [
            (.commonKeyTitle, \.title),
            (.commonKeyArtist, \.artist),
            (.commonKeyAlbumName, \.album)
        ]

        for (key, keyPath) in commonKeys {
            if let item = AVMetadataItem.metadataItems(
                from: asset.commonMetadata,
                filteredByIdentifier: AVMetadataIdentifier.commonIdentifier(for: key) ?? .commonIdentifierTitle
            ).first,
               let value = item.stringValue {
                metadata[keyPath: keyPath] = value
            }
        }

        // Try to get genre
        let genreItems = AVMetadataItem.metadataItems(
            from: asset.metadata,
            filteredByIdentifier: .id3MetadataContentType
        ) + AVMetadataItem.metadataItems(
            from: asset.metadata,
            filteredByIdentifier: .iTunesMetadataUserGenre
        )

        if let genreItem = genreItems.first, let genre = genreItem.stringValue {
            metadata.genre = genre
        }

        // Try to get year
        let yearItems = AVMetadataItem.metadataItems(
            from: asset.metadata,
            filteredByIdentifier: .id3MetadataYear
        ) + AVMetadataItem.metadataItems(
            from: asset.metadata,
            filteredByIdentifier: .iTunesMetadataReleaseDate
        )

        if let yearItem = yearItems.first, let year = yearItem.stringValue {
            metadata.year = String(year.prefix(4))
        }
    }

    // MARK: - CRUD Operations

    /// Update metadata for a song
    /// - Parameters:
    ///   - id: The song ID
    ///   - title: New title (optional)
    ///   - artist: New artist (optional)
    ///   - album: New album (optional)
    ///   - genre: New genre (optional)
    ///   - year: New year (optional)
    ///   - comments: New comments (optional)
    public func updateMetadata(
        for id: UUID,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        genre: String? = nil,
        year: String? = nil,
        comments: String? = nil
    ) {
        guard let index = songs.firstIndex(where: { $0.id == id }) else {
            return
        }

        if let title = title { songs[index].title = title }
        if let artist = artist { songs[index].artist = artist }
        if let album = album { songs[index].album = album }
        if let genre = genre { songs[index].genre = genre }
        if let year = year { songs[index].year = year }
        if let comments = comments { songs[index].comments = comments }

        songs[index].dateModified = Date()
        saveLibrary()
    }

    /// Rename a song file
    /// - Parameters:
    ///   - id: The song ID
    ///   - newName: The new filename (without extension)
    /// - Returns: True if rename was successful
    @discardableResult
    public func renameFile(for id: UUID, to newName: String) -> Bool {
        guard let index = songs.firstIndex(where: { $0.id == id }),
              let oldURL = songs[index].fileURL,
              let audioDirectory = Self.getAudioDirectory() else {
            return false
        }

        let ext = songs[index].fileExtension
        let newFileName = "\(newName).\(ext)"
        let newURL = audioDirectory.appendingPathComponent(newFileName)

        // Check if new name already exists
        if FileManager.default.fileExists(atPath: newURL.path) {
            lastError = "A file with this name already exists"
            return false
        }

        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            songs[index].fileName = newFileName
            songs[index].dateModified = Date()
            saveLibrary()
            return true
        } catch {
            lastError = "Failed to rename file: \(error.localizedDescription)"
            return false
        }
    }

    /// Delete a song from the library
    /// - Parameter id: The song ID
    /// - Returns: True if deletion was successful
    @discardableResult
    public func deleteSong(id: UUID) -> Bool {
        guard let index = songs.firstIndex(where: { $0.id == id }),
              let url = songs[index].fileURL else {
            return false
        }

        do {
            try FileManager.default.removeItem(at: url)
            songs.remove(at: index)
            saveLibrary()
            return true
        } catch {
            lastError = "Failed to delete file: \(error.localizedDescription)"
            return false
        }
    }

    /// Delete multiple songs from the library
    /// - Parameter ids: Array of song IDs
    /// - Returns: Number of successfully deleted songs
    public func deleteSongs(ids: Set<UUID>) -> Int {
        var deleted = 0
        for id in ids {
            if deleteSong(id: id) {
                deleted += 1
            }
        }
        return deleted
    }

    /// Get a song by ID
    public func getSong(id: UUID) -> SongMetadata? {
        songs.first { $0.id == id }
    }

    /// Get a song by file URL
    public func getSong(for url: URL) -> SongMetadata? {
        songs.first { $0.fileName == url.lastPathComponent }
    }

    // MARK: - Sorting & Filtering

    /// Sort option for library
    public enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case title = "Title"
        case artist = "Artist"
        case album = "Album"
        case duration = "Duration"
        case fileSize = "File Size"
    }

    /// Get songs sorted by option
    public func getSortedSongs(by option: SortOption, ascending: Bool = true) -> [SongMetadata] {
        let sorted: [SongMetadata]

        switch option {
        case .dateAdded:
            sorted = songs.sorted { $0.dateAdded < $1.dateAdded }
        case .title:
            sorted = songs.sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        case .artist:
            sorted = songs.sorted { $0.displayArtist.localizedCaseInsensitiveCompare($1.displayArtist) == .orderedAscending }
        case .album:
            sorted = songs.sorted { $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending }
        case .duration:
            sorted = songs.sorted { $0.duration < $1.duration }
        case .fileSize:
            sorted = songs.sorted { $0.fileSize < $1.fileSize }
        }

        return ascending ? sorted : sorted.reversed()
    }

    /// Search songs by query
    public func searchSongs(query: String) -> [SongMetadata] {
        guard !query.isEmpty else { return songs }

        let lowercaseQuery = query.lowercased()
        return songs.filter { song in
            song.displayTitle.lowercased().contains(lowercaseQuery) ||
            song.displayArtist.lowercased().contains(lowercaseQuery) ||
            song.album.lowercased().contains(lowercaseQuery) ||
            song.genre.lowercased().contains(lowercaseQuery)
        }
    }

    // MARK: - Statistics

    /// Total number of songs in library
    public var songCount: Int { songs.count }

    /// Total duration of all songs
    public var totalDuration: TimeInterval {
        songs.reduce(0) { $0 + $1.duration }
    }

    /// Total file size of all songs
    public var totalFileSize: Int64 {
        songs.reduce(0) { $0 + $1.fileSize }
    }

    /// Formatted total duration
    public var totalDurationFormatted: String {
        let hours = Int(totalDuration) / 3600
        let mins = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins) min"
    }

    /// Formatted total file size
    public var totalFileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalFileSize)
    }
}

// MARK: - Library Errors

public enum LibraryError: LocalizedError {
    case directoryNotFound
    case metadataExtractionFailed
    case fileAlreadyExists
    case fileNotFound
    case renameFailed
    case deleteFailed

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound:
            return "Could not access audio directory"
        case .metadataExtractionFailed:
            return "Could not read audio file information"
        case .fileAlreadyExists:
            return "A file with this name already exists"
        case .fileNotFound:
            return "The audio file could not be found"
        case .renameFailed:
            return "Could not rename the file"
        case .deleteFailed:
            return "Could not delete the file"
        }
    }
}

// MARK: - AVMetadataKey Extension

private extension AVMetadataIdentifier {
    static func commonIdentifier(for key: AVMetadataKey) -> AVMetadataIdentifier? {
        switch key {
        case .commonKeyTitle:
            return .commonIdentifierTitle
        case .commonKeyArtist:
            return .commonIdentifierArtist
        case .commonKeyAlbumName:
            return .commonIdentifierAlbumName
        default:
            return nil
        }
    }
}
