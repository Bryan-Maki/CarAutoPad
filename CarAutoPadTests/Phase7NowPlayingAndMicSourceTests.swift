import XCTest
import Foundation
@testable import CarAutoPad

final class Phase7NowPlayingAndMicSourceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ProjectionSettings.resetToDefaults()
    }

    override func tearDown() {
        ProjectionSettings.resetToDefaults()
        super.tearDown()
    }

    func testMicrophoneSourceEnumMetadata() {
        XCTAssertEqual(MicrophoneSource.followAudioOutput.rawValue, 0)
        XCTAssertEqual(MicrophoneSource.ipad.rawValue, 1)
        XCTAssertEqual(MicrophoneSource.phone.rawValue, 2)

        XCTAssertEqual(MicrophoneSource.followAudioOutput.title, "Follow Audio Output")
        XCTAssertEqual(MicrophoneSource.ipad.title, "iPad Microphone")
        XCTAssertEqual(MicrophoneSource.phone.title, "Phone / Car BT Mic")
    }

    func testEffectiveUseIpadMicWhenFollowAudioOutput() {
        ProjectionSettings.microphoneSource = .followAudioOutput

        ProjectionSettings.audioOutputTarget = .ipad
        XCTAssertTrue(ProjectionSettings.effectiveUseIpadMic, "Should use iPad mic when audio output is iPad")

        ProjectionSettings.audioOutputTarget = .phone
        XCTAssertFalse(ProjectionSettings.effectiveUseIpadMic, "Should not use iPad mic when audio output is Phone")
    }

    func testEffectiveUseIpadMicWhenForcedIpad() {
        ProjectionSettings.microphoneSource = .ipad

        ProjectionSettings.audioOutputTarget = .ipad
        XCTAssertTrue(ProjectionSettings.effectiveUseIpadMic)

        ProjectionSettings.audioOutputTarget = .phone
        XCTAssertTrue(ProjectionSettings.effectiveUseIpadMic, "Should still use iPad mic even if audio is routed to phone")
    }

    func testEffectiveUseIpadMicWhenForcedPhone() {
        ProjectionSettings.microphoneSource = .phone

        ProjectionSettings.audioOutputTarget = .ipad
        XCTAssertFalse(ProjectionSettings.effectiveUseIpadMic, "Should not use iPad mic if phone mic is forced")

        ProjectionSettings.audioOutputTarget = .phone
        XCTAssertFalse(ProjectionSettings.effectiveUseIpadMic)
    }

    func testServiceDiscoveryResponseWithMicEnabled() throws {
        let message = AapServiceDiscoveryResponseMessage.make(
            useMic: true,
            vehicleId: "iPad-CarAutoPad"
        )

        var reader = ProtoReader(data: message.payload)
        let proto = try ServiceDiscoveryResponseProto(from: &reader)

        let micService = proto.services.first(where: { $0.id == UInt32(Channel.ID_MIC) })
        XCTAssertNotNil(micService, "Service discovery response must include MIC service when useMic is true")

        XCTAssertEqual(proto.headunitInfo?.vehicleType, 3, "Vehicle type should be Unified Motorcycle Profile (3)")
        XCTAssertEqual(proto.headunitInfo?.vehicleId, "iPad-CarAutoPad-moto")
        XCTAssertEqual(proto.vehicleId, "iPad-CarAutoPad-moto")
        XCTAssertTrue(proto.vehicleId.hasSuffix("-moto"))
    }

    func testServiceDiscoveryResponseWithMicDisabledMaintainsSingleIdentity() throws {
        let message = AapServiceDiscoveryResponseMessage.make(
            useMic: false,
            vehicleId: "iPad-CarAutoPad"
        )

        var reader = ProtoReader(data: message.payload)
        let proto = try ServiceDiscoveryResponseProto(from: &reader)

        let micService = proto.services.first(where: { $0.id == UInt32(Channel.ID_MIC) })
        XCTAssertNil(micService, "Service discovery response must omit MIC service when useMic is false")

        XCTAssertEqual(proto.headunitInfo?.vehicleType, 3, "Vehicle type must remain Unified Profile (3) even when mic is omitted")
        XCTAssertEqual(proto.headunitInfo?.vehicleId, "iPad-CarAutoPad-moto")
        XCTAssertEqual(proto.vehicleId, "iPad-CarAutoPad-moto")
        XCTAssertTrue(proto.vehicleId.hasSuffix("-moto"))
    }

    func testMediaMetaDataSerializationAndDeserialization() throws {
        let artBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D])
        let original = MediaMetaData(
            song: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            albumArt: artBytes,
            playlist: "Favorites",
            durationSeconds: 200,
            rating: 5
        )

        var writer = ProtoWriter()
        original.encode(to: &writer)
        let encodedData = writer.data

        XCTAssertFalse(encodedData.isEmpty)

        var reader = ProtoReader(data: encodedData)
        let decoded = try MediaMetaData(from: &reader)

        XCTAssertEqual(decoded.song, "Blinding Lights")
        XCTAssertEqual(decoded.artist, "The Weeknd")
        XCTAssertEqual(decoded.album, "After Hours")
        XCTAssertEqual(decoded.albumArt, artBytes)
        XCTAssertEqual(decoded.playlist, "Favorites")
        XCTAssertEqual(decoded.durationSeconds, 200)
        XCTAssertEqual(decoded.rating, 5)
    }

    func testMediaPlaybackStatusSerializationAndDeserialization() throws {
        let original = MediaPlaybackStatus(
            state: .playing,
            mediaSource: "Apple Music",
            playbackSeconds: 125,
            shuffle: true,
            repeatMode: true,
            repeatOne: false
        )

        var writer = ProtoWriter()
        original.encode(to: &writer)
        let encodedData = writer.data

        XCTAssertFalse(encodedData.isEmpty)

        var reader = ProtoReader(data: encodedData)
        let decoded = try MediaPlaybackStatus(from: &reader)

        XCTAssertEqual(decoded.state, .playing)
        XCTAssertEqual(decoded.mediaSource, "Apple Music")
        XCTAssertEqual(decoded.playbackSeconds, 125)
        XCTAssertEqual(decoded.shuffle, true)
        XCTAssertEqual(decoded.repeatMode, true)
        XCTAssertEqual(decoded.repeatOne, false)
    }

    func testSettingsBackupManagerRoundTripWithPhase7Properties() throws {
        ProjectionSettings.isAutoDpi = false
        ProjectionSettings.dpi = 220
        ProjectionSettings.microphoneSource = .phone
        ProjectionSettings.audioOutputTarget = .phone

        let json = SettingsBackupManager.exportToJson()
        XCTAssertTrue(json.contains("\"isAutoDpi\" : false"))
        XCTAssertTrue(json.contains("\"microphoneSource\" : 2"))

        ProjectionSettings.resetToDefaults()
        XCTAssertTrue(ProjectionSettings.isAutoDpi)
        XCTAssertEqual(ProjectionSettings.microphoneSource, .followAudioOutput)

        let count = try SettingsBackupManager.importFromJson(json)
        XCTAssertEqual(count, 14)
        XCTAssertFalse(ProjectionSettings.isAutoDpi)
        XCTAssertEqual(ProjectionSettings.dpi, 220)
        XCTAssertEqual(ProjectionSettings.microphoneSource, .phone)
        XCTAssertEqual(ProjectionSettings.audioOutputTarget, .phone)
        XCTAssertFalse(ProjectionSettings.effectiveUseIpadMic)
    }

    func testSettingsBackupManagerLegacyJsonCompatibilityWithoutPhase7Fields() throws {
        let legacyJson = """
        {
          "exportedAt" : "2026-10-17T00:00:00Z",
          "format" : "carautopad-settings",
          "settings" : {
            "audioCodecPreference" : 1,
            "audioOutputTarget" : 0,
            "autoReconnect" : true,
            "autoResumePlayback" : true,
            "dpi" : 180,
            "fitMode" : 1,
            "fpsLimit" : 1,
            "gpsSource" : 0,
            "nightMode" : 0,
            "orientation" : 0,
            "resolution" : 0,
            "rightHandDrive" : false,
            "showPerformanceOverlay" : false,
            "videoCodecPreference" : "h264"
          },
          "version" : 1
        }
        """

        ProjectionSettings.microphoneSource = .phone
        ProjectionSettings.isAutoDpi = false

        let count = try SettingsBackupManager.importFromJson(legacyJson)
        XCTAssertEqual(count, 14)
        XCTAssertEqual(ProjectionSettings.dpi, 180)
        XCTAssertEqual(ProjectionSettings.microphoneSource, .phone)
        XCTAssertFalse(ProjectionSettings.isAutoDpi)
    }
}
