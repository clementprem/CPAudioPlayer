import XCTest
@testable import CPAudioPlayer
@testable import CPAudioPlayerUI

final class CPAudioPlayerTests: XCTestCase {

    func testAudioPlayerInitialization() throws {
        let player = AudioPlayer()
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.currentTime, 0)
        XCTAssertEqual(player.duration, 0)
        XCTAssertEqual(player.eqBands.count, 7)
    }

    func testEQPresets() throws {
        XCTAssertFalse(AudioPlayer.presets.isEmpty)
        XCTAssertNotNil(AudioPlayer.presets["Flat"])
        XCTAssertNotNil(AudioPlayer.presets["Rock"])
        XCTAssertNotNil(AudioPlayer.presets["Jazz"])
    }

    func testDefaultFrequencies() throws {
        let frequencies = AudioPlayer.defaultFrequencies
        XCTAssertEqual(frequencies.count, 7)
        XCTAssertEqual(frequencies[0], 60)
        XCTAssertEqual(frequencies[6], 16000)
    }

    func testEQBandSetting() throws {
        let player = AudioPlayer()
        player.setEQ(value: 5, forBand: 0)
        XCTAssertEqual(player.eqBands[0], 5)
    }

    func testResetEQ() throws {
        let player = AudioPlayer()
        player.setEQBands([1, 2, 3, 4, 5, 6, 7])
        player.resetEQ()
        XCTAssertTrue(player.eqBands.allSatisfy { $0 == 0 })
    }

    func testApplyPreset() throws {
        let player = AudioPlayer()
        player.applyPreset("Bass Boost")
        XCTAssertEqual(player.eqBands[0], 6)
        XCTAssertEqual(player.eqBands[1], 4)
        XCTAssertEqual(player.eqBands[2], 2)
    }

    func testTimeFormatting() throws {
        let player = AudioPlayer()
        // Test formatting through convenience extension
        XCTAssertEqual(player.currentTimeFormatted, "0:00")
        XCTAssertEqual(player.durationFormatted, "0:00")
    }
}
