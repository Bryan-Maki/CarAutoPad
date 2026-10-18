import XCTest
import CoreLocation
@testable import CarAutoPad

final class Phase9SmartFeaturesAndResilienceTests: XCTestCase {

    func testTwilightCalculatorCalculatesDayAndNightAccurately() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var noonComponents = DateComponents()
        noonComponents.year = 2024
        noonComponents.month = 6
        noonComponents.day = 21
        noonComponents.hour = 12
        noonComponents.minute = 0
        noonComponents.second = 0
        let londonNoon = calendar.date(from: noonComponents)!

        let isNightAtNoon = TwilightCalculator.isNight(
            date: londonNoon,
            latitude: 51.5074,
            longitude: -0.1278,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        XCTAssertFalse(isNightAtNoon, "Noon on summer solstice in London must be daytime")

        var midnightComponents = DateComponents()
        midnightComponents.year = 2024
        midnightComponents.month = 6
        midnightComponents.day = 21
        midnightComponents.hour = 0
        midnightComponents.minute = 0
        midnightComponents.second = 0
        let londonMidnight = calendar.date(from: midnightComponents)!

        let isNightAtMidnight = TwilightCalculator.isNight(
            date: londonMidnight,
            latitude: 51.5074,
            longitude: -0.1278,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        XCTAssertTrue(isNightAtMidnight, "Midnight in London must be nighttime")
    }

    func testTwilightCalculatorPolarNightAndMidnightSun() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var winterNoon = DateComponents()
        winterNoon.year = 2024
        winterNoon.month = 12
        winterNoon.day = 21
        winterNoon.hour = 11
        winterNoon.minute = 0
        let tromsoWinterNoon = calendar.date(from: winterNoon)!

        let winterResult = TwilightCalculator.calculateTwilight(
            timeMillis: Int64(tromsoWinterNoon.timeIntervalSince1970 * 1000),
            latitude: 69.6492,
            longitude: 18.9553
        )
        XCTAssertEqual(winterResult.state, .night, "Polar night in Tromsø must evaluate to NIGHT")
    }

    func testTwilightCalculatorOfflineTimezoneFallback() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        var tokyoNoon = DateComponents()
        tokyoNoon.year = 2024
        tokyoNoon.month = 4
        tokyoNoon.day = 15
        tokyoNoon.hour = 12
        tokyoNoon.minute = 0
        let dateNoon = calendar.date(from: tokyoNoon)!

        let isNightOffline = TwilightCalculator.isNight(
            date: dateNoon,
            latitude: nil,
            longitude: nil,
            timeZone: TimeZone(identifier: "Asia/Tokyo")!
        )
        XCTAssertFalse(isNightOffline, "Noon in Tokyo using offline timezone fallback must be daytime")

        var tokyoNight = DateComponents()
        tokyoNight.year = 2024
        tokyoNight.month = 4
        tokyoNight.day = 15
        tokyoNight.hour = 23
        tokyoNight.minute = 0
        let dateNight = calendar.date(from: tokyoNight)!

        let isNightAt11pm = TwilightCalculator.isNight(
            date: dateNight,
            latitude: nil,
            longitude: nil,
            timeZone: TimeZone(identifier: "Asia/Tokyo")!
        )
        XCTAssertTrue(isNightAt11pm, "11pm in Tokyo using offline timezone fallback must be nighttime")
    }

    func testProjectionSettingsEffectiveIsNightModeTwilightMode() {
        let prevNight = ProjectionSettings.nightMode
        let prevLat = ProjectionSettings.lastKnownLatitude
        let prevLon = ProjectionSettings.lastKnownLongitude
        defer {
            ProjectionSettings.nightMode = prevNight
            ProjectionSettings.lastKnownLatitude = prevLat
            ProjectionSettings.lastKnownLongitude = prevLon
        }

        ProjectionSettings.nightMode = .twilight
        ProjectionSettings.recordLastKnownLocation(latitude: 37.7749, longitude: -122.4194)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        var sfNoon = DateComponents()
        sfNoon.year = 2024
        sfNoon.month = 5
        sfNoon.day = 10
        sfNoon.hour = 13
        sfNoon.minute = 0
        let noonDate = calendar.date(from: sfNoon)!

        XCTAssertFalse(ProjectionSettings.effectiveIsNightMode(now: noonDate), "SF at 1pm in May must be DAY in Twilight mode")

        var sfMidnight = DateComponents()
        sfMidnight.year = 2024
        sfMidnight.month = 5
        sfMidnight.day = 10
        sfMidnight.hour = 1
        sfMidnight.minute = 0
        let midnightDate = calendar.date(from: sfMidnight)!

        XCTAssertTrue(ProjectionSettings.effectiveIsNightMode(now: midnightDate), "SF at 1am in May must be NIGHT in Twilight mode")
    }

    func testSensorBatchLocationDataNegativeCoordinatesSerialization() throws {
        let sfLat: Int32 = 377749000
        let sfLon: Int32 = -1224194000
        let sfAlt: Int32 = -8600

        let locSF = SensorBatch.LocationData(
            timestamp: 1715340000000,
            latitude: sfLat,
            longitude: sfLon,
            accuracy: 5000,
            altitude: sfAlt,
            speed: 25000,
            bearing: 180000000
        )

        var writer = ProtoWriter()
        let batch = SensorBatch(locationData: [locSF])
        batch.encode(to: &writer)
        let encodedData = writer.data

        XCTAssertFalse(encodedData.isEmpty)

        var reader = ProtoReader(data: encodedData)
        let decodedBatch = try SensorBatch(from: &reader)
        XCTAssertEqual(decodedBatch.locationData.count, 1)

        let decodedLoc = decodedBatch.locationData[0]
        XCTAssertEqual(decodedLoc.latitude, sfLat, "Latitude 37.7749° must match")
        XCTAssertEqual(decodedLoc.longitude, sfLon, "Negative longitude -122.4194° must be preserved without zero-clamping")
        XCTAssertEqual(decodedLoc.altitude, sfAlt, "Negative altitude -86.00m must be preserved without zero-clamping")
        XCTAssertEqual(decodedLoc.speed, 25000)
        XCTAssertEqual(decodedLoc.bearing, 180000000)

        let sydLat: Int32 = -338688000
        let sydLon: Int32 = 1512093000
        let locSyd = SensorBatch.LocationData(
            timestamp: 1715340000000,
            latitude: sydLat,
            longitude: sydLon,
            accuracy: 3000
        )

        var sydWriter = ProtoWriter()
        SensorBatch(locationData: [locSyd]).encode(to: &sydWriter)
        var sydReader = ProtoReader(data: sydWriter.data)
        let decodedSydBatch = try SensorBatch(from: &sydReader)
        XCTAssertEqual(decodedSydBatch.locationData[0].latitude, sydLat, "Negative latitude -33.8688° must be preserved")
        XCTAssertEqual(decodedSydBatch.locationData[0].longitude, sydLon, "Longitude 151.2093° must match")
    }

    func testKeymapManagerMappings() {
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardUpArrow), AndroidKeyCode.DPAD_UP)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardDownArrow), AndroidKeyCode.DPAD_DOWN)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardLeftArrow), AndroidKeyCode.DPAD_LEFT)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardRightArrow), AndroidKeyCode.DPAD_RIGHT)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardReturnOrEnter), AndroidKeyCode.DPAD_CENTER)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keypadEnter), AndroidKeyCode.DPAD_CENTER)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardEscape), AndroidKeyCode.BACK)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardHome), AndroidKeyCode.HOME)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardH), AndroidKeyCode.HOME)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardTab), AndroidKeyCode.TAB)

        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardSpacebar), AndroidKeyCode.MEDIA_PLAY_PAUSE)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardN), AndroidKeyCode.MEDIA_NEXT)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardF9), AndroidKeyCode.MEDIA_NEXT)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardP), AndroidKeyCode.MEDIA_PREVIOUS)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardF7), AndroidKeyCode.MEDIA_PREVIOUS)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardS), AndroidKeyCode.MEDIA_STOP)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardF8), AndroidKeyCode.MEDIA_STOP)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardV), AndroidKeyCode.SEARCH)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardF), AndroidKeyCode.SEARCH)

        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardOpenBracket), AndroidKeyCode.SOFT_LEFT)
        XCTAssertEqual(KeymapManager.androidKeyCode(for: .keyboardCloseBracket), AndroidKeyCode.SOFT_RIGHT)

        XCTAssertNil(KeymapManager.androidKeyCode(for: .keyboardA))
    }

    func testDecoderConfigLadderFallbackChain() {
        XCTAssertEqual(DecoderConfigLadder.fallbackPreset(from: .r3840x2160), .r2560x1440)
        XCTAssertEqual(DecoderConfigLadder.fallbackPreset(from: .r2560x1440), .r1920x1080)
        XCTAssertEqual(DecoderConfigLadder.fallbackPreset(from: .r1920x1080), .r1280x720)
        XCTAssertEqual(DecoderConfigLadder.fallbackPreset(from: .r1280x720), .r800x480)
        XCTAssertNil(DecoderConfigLadder.fallbackPreset(from: .r800x480))

        XCTAssertEqual(DecoderConfigLadder.fallbackPreset(from: .auto, currentWidth: 3840, currentHeight: 2160), .r2560x1440)
        XCTAssertEqual(DecoderConfigLadder.fallbackPreset(from: .auto, currentWidth: 1920, currentHeight: 1080), .r1280x720)
        XCTAssertEqual(DecoderConfigLadder.fallbackPreset(from: .auto, currentWidth: 1280, currentHeight: 720), .r800x480)
        XCTAssertNil(DecoderConfigLadder.fallbackPreset(from: .auto, currentWidth: 800, currentHeight: 480))
    }

    func testNetworkReachabilitySnapshotEquality() {
        let snap1 = NetworkReachabilitySnapshot(isWifiConnected: true, stationIpv4: "192.168.43.15", gatewayIpv4: "192.168.43.1")
        let snap2 = NetworkReachabilitySnapshot(isWifiConnected: true, stationIpv4: "192.168.43.15", gatewayIpv4: "192.168.43.1")
        let snap3 = NetworkReachabilitySnapshot(isWifiConnected: false, stationIpv4: nil, gatewayIpv4: nil)

        XCTAssertEqual(snap1, snap2)
        XCTAssertNotEqual(snap1, snap3)
    }

    func testNetworkReachabilityMonitorEvaluateNow() {
        let snapshot = NetworkReachabilityMonitor.shared.evaluateNow()
        XCTAssertNotNil(snapshot)
        if snapshot.isWifiConnected {
            XCTAssertNotNil(snapshot.stationIpv4)
            XCTAssertNotNil(snapshot.gatewayIpv4)
        } else {
            XCTAssertNil(snapshot.stationIpv4)
            XCTAssertNil(snapshot.gatewayIpv4)
        }
    }
}
