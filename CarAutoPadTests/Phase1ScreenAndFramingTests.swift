import XCTest
@testable import CarAutoPad

final class Phase1ScreenAndFramingTests: XCTestCase {

    func testProtoWirePrimitives() throws {
        var writer = ProtoWriter()
        writer.writeVarint(field: 1, value: 42)
        writer.writeZigZag64(field: 2, value: -100)
        writer.writeFixed32(field: 3, value: 0x12345678)
        writer.writeFixed64(field: 4, value: 0x1122334455667788)
        writer.writeString(field: 5, value: "CarAutoPad")
        writer.writeBytes(field: 6, value: Data([0xDE, 0xAD, 0xBE, 0xEF]))

        let encoded = writer.data
        var reader = ProtoReader(data: encoded)

        var foundVarint: UInt64?
        var foundZigZag: Int64?
        var foundFixed32: UInt32?
        var foundFixed64: UInt64?
        var foundString: String?
        var foundBytes: Data?

        while let tag = try reader.nextTag() {
            switch tag.fieldNumber {
            case 1:
                foundVarint = try reader.readVarint()
            case 2:
                foundZigZag = try reader.readZigZag64()
            case 3:
                foundFixed32 = try reader.readFixed32()
            case 4:
                foundFixed64 = try reader.readFixed64()
            case 5:
                foundString = try reader.readString()
            case 6:
                foundBytes = try reader.readBytes()
            default:
                try reader.skipField(wireType: tag.wireType)
            }
        }

        XCTAssertEqual(foundVarint, 42)
        XCTAssertEqual(foundZigZag, -100)
        XCTAssertEqual(foundFixed32, 0x12345678)
        XCTAssertEqual(foundFixed64, 0x1122334455667788)
        XCTAssertEqual(foundString, "CarAutoPad")
        XCTAssertEqual(foundBytes, Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }

    func testAapMessageFramingFlags() {
        XCTAssertTrue(AapMessageFraming.isLast(flags: Int(AapFlags.NORMAL_MESSAGE)))
        XCTAssertTrue(AapMessageFraming.carriesMessageType(flags: Int(AapFlags.NORMAL_MESSAGE)))
        XCTAssertFalse(AapMessageFraming.carriesTotalLength(flags: Int(AapFlags.NORMAL_MESSAGE)))

        let firstOnlyFlag: Int = 0x09
        XCTAssertTrue(AapMessageFraming.carriesMessageType(flags: firstOnlyFlag))
        XCTAssertFalse(AapMessageFraming.isLast(flags: firstOnlyFlag))
        XCTAssertTrue(AapMessageFraming.carriesTotalLength(flags: firstOnlyFlag))

        let middleFlag: Int = 0x08
        XCTAssertFalse(AapMessageFraming.carriesMessageType(flags: middleFlag))
        XCTAssertFalse(AapMessageFraming.isLast(flags: middleFlag))
        XCTAssertFalse(AapMessageFraming.carriesTotalLength(flags: middleFlag))

        let lastFlag: Int = 0x0a
        XCTAssertFalse(AapMessageFraming.carriesMessageType(flags: lastFlag))
        XCTAssertTrue(AapMessageFraming.isLast(flags: lastFlag))
        XCTAssertFalse(AapMessageFraming.carriesTotalLength(flags: lastFlag))
    }

    func testSingleFragmentReassembly() throws {
        let reassembler = AapMessageReassembler()
        var payload = Data([0x80, 0x01])
        payload.append(contentsOf: [1, 2, 3, 4, 5])

        let fragment = AapMessage(
            channel: Int(Channel.ID_CTR),
            flags: 0x0b,
            type: 0x8001,
            dataOffset: 2,
            size: payload.count,
            data: payload
        )

        let result = try reassembler.accept(fragment: fragment, declaredTotal: payload.count)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.channel, Int(Channel.ID_CTR))
        XCTAssertEqual(result?.type, 0x8001)
        XCTAssertEqual(result?.payload, Data([1, 2, 3, 4, 5]))
    }

    func testMultiFragmentReassembly() throws {
        let reassembler = AapMessageReassembler()
        let audit = FragmentedMessageAudit()

        let totalLen = 10
        var frag1Data = Data([0x80, 0x03])
        frag1Data.append(contentsOf: [10, 20, 30])

        let frag2Data = Data([40, 50, 60, 70, 80])

        let frag1 = AapMessage(
            channel: Int(Channel.ID_MPB),
            flags: 0x09,
            type: 0x8003,
            dataOffset: 2,
            size: frag1Data.count,
            data: frag1Data
        )

        let frag2 = AapMessage(
            channel: Int(Channel.ID_MPB),
            flags: 0x0a,
            type: -1,
            dataOffset: 0,
            size: frag2Data.count,
            data: frag2Data
        )

        let a1 = audit.onMessage(channel: Int(Channel.ID_MPB), flags: 0x09, plaintextLength: 5, declaredTotal: totalLen)
        XCTAssertNil(a1)

        let r1 = try reassembler.accept(fragment: frag1, declaredTotal: totalLen)
        XCTAssertNil(r1, "First fragment should not finish reassembly")

        let a2 = audit.onMessage(channel: Int(Channel.ID_MPB), flags: 0x0a, plaintextLength: 5, declaredTotal: 0)
        XCTAssertNil(a2, "Normal completion should produce no audit issue")

        let r2 = try reassembler.accept(fragment: frag2, declaredTotal: 0)
        XCTAssertNotNil(r2, "Second fragment should complete assembly")
        XCTAssertEqual(r2?.channel, Int(Channel.ID_MPB))
        XCTAssertEqual(r2?.type, 0x8003)
        XCTAssertEqual(r2?.size, 10)
        XCTAssertEqual(r2?.payload, Data([10, 20, 30, 40, 50, 60, 70, 80]))
    }

    func testStreamingVideoFragmentsYieldedImmediately() throws {
        let reassembler = AapMessageReassembler()

        var videoPrefix = Data([0x00, 0x00])
        videoPrefix.append(contentsOf: [UInt8](repeating: 0xAA, count: 20))

        let frag1 = AapMessage(
            channel: Int(Channel.ID_VID),
            flags: 0x09,
            type: 0,
            dataOffset: 2,
            size: videoPrefix.count,
            data: videoPrefix
        )

        let r1 = try reassembler.accept(fragment: frag1, declaredTotal: 50)
        XCTAssertNotNil(r1, "Video fragment 1 should be yielded immediately for streaming low-latency decoding")
        XCTAssertEqual(r1?.flags, 0x09)
        XCTAssertEqual(r1?.type, 0)

        let frag2Data = Data([UInt8](repeating: 0xBB, count: 28))
        let frag2 = AapMessage(
            channel: Int(Channel.ID_VID),
            flags: 0x0a,
            type: -1,
            dataOffset: 0,
            size: frag2Data.count,
            data: frag2Data
        )

        let r2 = try reassembler.accept(fragment: frag2, declaredTotal: 0)
        XCTAssertNotNil(r2, "Video fragment 2 (last) should be yielded immediately")
        XCTAssertEqual(r2?.flags, 0x0a)
    }

    func testFragmentAuditDiscrepancyDetection() {
        let audit = FragmentedMessageAudit()

        _ = audit.onMessage(channel: 1, flags: 0x09, plaintextLength: 4, declaredTotal: 10)

        let issue = audit.onMessage(channel: 1, flags: 0x0a, plaintextLength: 3, declaredTotal: 0)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.outcome, .deltaChanged)
        XCTAssertEqual(issue?.delta, 3)

        let orphan = audit.onMessage(channel: 1, flags: 0x08, plaintextLength: 5, declaredTotal: 0)
        XCTAssertNotNil(orphan)
        XCTAssertEqual(orphan?.outcome, .orphanedFragment)
    }

    func testIpadScreenConfigFillMarginMode() {
        let config = HeadUnitScreenConfig.shared
        _ = config.updateDimensions(width: 2048, height: 1536)
        config.videoFitMode = .fillMargin
        config.negotiatedResolutionType = ._1920x1080
        config.recalculate()

        let widthMargin = config.getWidthMargin()
        let heightMargin = config.getHeightMargin()

        XCTAssertEqual(widthMargin, 480)
        XCTAssertEqual(heightMargin, 0)
        XCTAssertEqual(config.getLeftMargin(), 240)
        XCTAssertEqual(config.getRightMargin(), 240)
        XCTAssertEqual(config.getTopMargin(), 0)
        XCTAssertEqual(config.getBottomMargin(), 0)

        let visibleW = config.getNegotiatedWidth() - widthMargin
        let visibleH = config.getNegotiatedHeight() - heightMargin
        XCTAssertEqual(visibleW, 1440)
        XCTAssertEqual(visibleH, 1080)
        XCTAssertEqual(Double(visibleW) / Double(visibleH), 4.0 / 3.0, accuracy: 0.001)
    }

    func testMarginStrategyPolicySelection() {
        let strategyFill = MarginStrategyPolicy.select(
            mode: .fillMargin,
            panelW: 2048,
            panelH: 1536,
            videoW: 1920,
            videoH: 1080
        )
        XCTAssertEqual(strategyFill, .margin)

        let strategyFit = MarginStrategyPolicy.select(
            mode: .fit,
            panelW: 2048,
            panelH: 1536,
            videoW: 1920,
            videoH: 1080
        )
        XCTAssertEqual(strategyFit, .par)
    }

    func testTouchCoordinateMapperFillMargin() {
        let mapper = TouchCoordinateMapper()
        let container = CGSize(width: 1024, height: 768)
        let videoSize = CGSize(width: 1920, height: 1080)

        let leftTouch = CGPoint(x: 0, y: 384)
        let pLeft = mapper.map(
            point: leftTouch,
            containerSize: container,
            videoSize: videoSize,
            mode: .fillMargin,
            marginW: 480,
            marginH: 0
        )
        XCTAssertEqual(pLeft.x, 0)
        XCTAssertEqual(pLeft.y, 540)

        let centerTouch = CGPoint(x: 512, y: 384)
        let pCenter = mapper.map(
            point: centerTouch,
            containerSize: container,
            videoSize: videoSize,
            mode: .fillMargin,
            marginW: 480,
            marginH: 0
        )
        XCTAssertEqual(pCenter.x, 720)
        XCTAssertEqual(pCenter.y, 540)

        let rightTouch = CGPoint(x: 1024, y: 384)
        let pRight = mapper.map(
            point: rightTouch,
            containerSize: container,
            videoSize: videoSize,
            mode: .fillMargin,
            marginW: 480,
            marginH: 0
        )
        XCTAssertEqual(pRight.x, 1440)
        XCTAssertEqual(pRight.y, 540)
    }

    func testTouchCoordinateMapperStretch() {
        let mapper = TouchCoordinateMapper()
        let container = CGSize(width: 1000, height: 500)
        let videoSize = CGSize(width: 1920, height: 1080)

        let point = CGPoint(x: 500, y: 250)
        let mapped = mapper.map(
            point: point,
            containerSize: container,
            videoSize: videoSize,
            mode: .stretch,
            marginW: 0,
            marginH: 0
        )

        XCTAssertEqual(mapped.x, 960)
        XCTAssertEqual(mapped.y, 540)
    }

    func testUpdateUiConfigRequestSerialization() throws {
        let msg = UpdateUiConfigRequest.make(left: 240, top: 0, right: 240, bottom: 0)

        XCTAssertEqual(msg.channel, Int(Channel.ID_VID))
        XCTAssertEqual(msg.type, Int(MediaMsgType.mediaMessageUpdateUiConfigRequest.rawValue))

        let payload = msg.payload
        var reader = ProtoReader(data: payload)
        let decoded = try UpdateUiConfigRequestProto(from: &reader)

        XCTAssertEqual(decoded.uiConfig.margins?.left, 240)
        XCTAssertEqual(decoded.uiConfig.margins?.top, 0)
        XCTAssertEqual(decoded.uiConfig.margins?.right, 240)
        XCTAssertEqual(decoded.uiConfig.margins?.bottom, 0)
    }

    func testAapTouchEventMessageSerialization() throws {
        let pointers = [(id: 0, x: 960, y: 540)]
        let msg = AapTouchEventMessage.make(
            timestampNs: 123456789,
            action: .press,
            actionIndex: 0,
            pointers: pointers
        )

        XCTAssertEqual(msg.channel, Int(Channel.ID_INP))
        XCTAssertEqual(msg.type, Int(InputMsgType.event.rawValue))

        var reader = ProtoReader(data: msg.payload)
        let report = try InputReport(from: &reader)

        XCTAssertEqual(report.timestamp, 123456789)
        XCTAssertEqual(report.touchEvent?.action, .press)
        XCTAssertEqual(report.touchEvent?.pointerData.count, 1)
        XCTAssertEqual(report.touchEvent?.pointerData.first?.x, 960)
        XCTAssertEqual(report.touchEvent?.pointerData.first?.y, 540)
    }

    func testServiceDiscoveryResponseSerialization() throws {
        let screenConfig = HeadUnitScreenConfig.shared
        screenConfig.initScreen(width: 2048, height: 1536, requestedResolution: .r1920x1080)
        screenConfig.videoFitMode = .fillMargin

        let msg = AapServiceDiscoveryResponseMessage.make(
            screenConfig: screenConfig,
            fpsLimit: 60,
            rightHandDrive: false,
            useGps: true,
            useMic: true,
            requestedDpi: 160
        )

        XCTAssertEqual(msg.channel, Int(Channel.ID_CTR))
        XCTAssertEqual(msg.type, Int(ControlMsgType.serviceDiscoveryResponse.rawValue))

        var reader = ProtoReader(data: msg.payload)
        let response = try ServiceDiscoveryResponseProto(from: &reader)

        XCTAssertFalse(response.services.isEmpty)

        let videoService = response.services.first(where: { $0.id == UInt32(Channel.ID_VID) })
        XCTAssertNotNil(videoService)
        let videoConfig = videoService?.mediaSinkService?.videoConfigs.first
        XCTAssertNotNil(videoConfig)
        XCTAssertEqual(videoConfig?.marginWidth, 480)
        XCTAssertEqual(videoConfig?.marginHeight, 0)

        let inputService = response.services.first(where: { $0.id == UInt32(Channel.ID_INP) })
        XCTAssertNotNil(inputService)
        XCTAssertEqual(inputService?.inputSourceService?.touchscreen?.width, 1920)
        XCTAssertEqual(inputService?.inputSourceService?.touchscreen?.height, 1080)
    }

    func testIpadAirAndProDynamicMargins() {
        let config = HeadUnitScreenConfig.shared

        _ = config.updateDimensions(width: 2360, height: 1640)
        config.videoFitMode = .fillMargin
        config.negotiatedResolutionType = ._1920x1080
        config.recalculate()

        XCTAssertEqual(config.getWidthMargin(), 366)
        XCTAssertEqual(config.getHeightMargin(), 0)
        XCTAssertEqual(config.getLeftMargin(), 183)
        XCTAssertEqual(config.getRightMargin(), 183)
        XCTAssertEqual(config.getLeftMargin() + config.getRightMargin(), config.getWidthMargin())

        _ = config.updateDimensions(width: 2388, height: 1668)
        config.videoFitMode = .fillMargin
        config.negotiatedResolutionType = ._1920x1080
        config.recalculate()

        XCTAssertEqual(config.getWidthMargin(), 374)
        XCTAssertEqual(config.getHeightMargin(), 0)
        XCTAssertEqual(config.getLeftMargin(), 187)
        XCTAssertEqual(config.getRightMargin(), 187)
    }

    func testIpadMiniDynamicMargins() {
        let config = HeadUnitScreenConfig.shared

        _ = config.updateDimensions(width: 2266, height: 1488)
        config.videoFitMode = .fillMargin
        config.negotiatedResolutionType = ._1920x1080
        config.recalculate()

        XCTAssertEqual(config.getWidthMargin(), 276)
        XCTAssertEqual(config.getHeightMargin(), 0)
        XCTAssertEqual(config.getLeftMargin(), 138)
        XCTAssertEqual(config.getRightMargin(), 138)
    }

    func testProjectionGeometryOverscanCalculations() {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 768)
        let activeW = 1440
        let activeH = 1080
        let codecW = 1920
        let codecH = 1080

        let activeRect = ProjectionGeometryPolicy.activeDisplayRect(
            bounds: bounds,
            activeW: activeW,
            activeH: activeH,
            fitMode: .fillMargin
        )
        XCTAssertEqual(activeRect, bounds)

        let layerFrame = ProjectionGeometryPolicy.overscanLayerFrame(
            activeRect: activeRect,
            codecW: codecW,
            codecH: codecH,
            activeW: activeW,
            activeH: activeH
        )

        let expectedW = bounds.width * (CGFloat(codecW) / CGFloat(activeW))
        let expectedH = bounds.height * (CGFloat(codecH) / CGFloat(activeH))
        XCTAssertEqual(layerFrame.width, expectedW, accuracy: 0.001)
        XCTAssertEqual(layerFrame.height, expectedH, accuracy: 0.001)

        XCTAssertLessThan(layerFrame.minX, 0)
        XCTAssertGreaterThan(layerFrame.maxX, bounds.width)
        XCTAssertEqual(abs(layerFrame.minX), layerFrame.maxX - bounds.width, accuracy: 0.001)
        XCTAssertEqual(layerFrame.midX, bounds.midX, accuracy: 0.001)
        XCTAssertEqual(layerFrame.midY, bounds.midY, accuracy: 0.001)
    }

    func testAnnouncedDensityPolicyRecommendations() {
        let miniBounds = CGRect(x: 0, y: 0, width: 1133, height: 744)
        let miniDpi = AnnouncedDensityPolicy.recommendedDpi(
            screenBounds: miniBounds,
            activeW: 1644,
            activeH: 1080
        )
        XCTAssertEqual(miniDpi, 160)

        let pro11Bounds = CGRect(x: 0, y: 0, width: 1194, height: 834)
        let pro11Dpi = AnnouncedDensityPolicy.recommendedDpi(
            screenBounds: pro11Bounds,
            activeW: 1546,
            activeH: 1080
        )
        XCTAssertEqual(pro11Dpi, 180)

        let pro12Bounds = CGRect(x: 0, y: 0, width: 1366, height: 1024)
        let pro12Dpi = AnnouncedDensityPolicy.recommendedDpi(
            screenBounds: pro12Bounds,
            activeW: 1440,
            activeH: 1080
        )
        XCTAssertEqual(pro12Dpi, 200)

        let pro12Dpi1440 = AnnouncedDensityPolicy.recommendedDpi(
            screenBounds: pro12Bounds,
            activeW: 1920,
            activeH: 1440
        )
        XCTAssertEqual(pro12Dpi1440, 240)
    }

    func testPortraitOrientationSelectsPortraitCodecResolutionAndMargins() {
        let prevOrientation = ProjectionSettings.orientation
        defer {
            ProjectionSettings.orientation = prevOrientation
            HeadUnitScreenConfig.shared.initScreen(width: 1920, height: 1080, requestedResolution: .r1920x1080)
        }

        ProjectionSettings.orientation = .portrait

        XCTAssertEqual(ResolutionPreset.r1920x1080.protoType(portrait: true), ._1080x1920)
        XCTAssertEqual(ResolutionPreset.r1280x720.protoType(portrait: true), ._720x1280)
        XCTAssertEqual(ResolutionPreset.r2560x1440.protoType(portrait: true), ._1440x2560)
        XCTAssertEqual(ResolutionPreset.r3840x2160.protoType(portrait: true), ._2160x3840)

        let config = HeadUnitScreenConfig.shared
        config.clearCustomNegotiatedResolution()
        config.initScreen(width: 1640, height: 2360, requestedResolution: .r1920x1080)

        XCTAssertTrue(config.isPortraitDisplay, "Portrait dimensions should report isPortraitDisplay == true")
        XCTAssertEqual(config.screenWidthPx, 1640)
        XCTAssertEqual(config.screenHeightPx, 2360)
        XCTAssertEqual(config.negotiatedResolutionType, ._1080x1920)
        XCTAssertEqual(config.getCodecResolution(), ._1080x1920)

        let active = config.activeSize()
        XCTAssertEqual(active.width, 1080)
        XCTAssertEqual(active.height, 1920)

        let (marginW, marginH) = config.getMargins()
        XCTAssertGreaterThanOrEqual(marginW, 0)
        XCTAssertGreaterThanOrEqual(marginH, 0)
    }

    func testFillMarginCrossOrientationDynamicMarginCalculation() {
        let config = HeadUnitScreenConfig.shared
        config.clearCustomNegotiatedResolution()
        config.clearAnnouncedMargins()

        let prevOrientation = ProjectionSettings.orientation
        defer {
            ProjectionSettings.orientation = prevOrientation
            config.clearCustomNegotiatedResolution()
            config.clearAnnouncedMargins()
            config.onMarginsDivergedDetailed = nil
        }

        ProjectionSettings.orientation = .system
        config.videoFitMode = .fillMargin
        config.negotiatedWidth = 1920
        config.negotiatedHeight = 1080
        config.isResolutionLocked = true

        config.recordAnnouncedMargins(widthMargin: 480, heightMargin: 0)

        var divergedMargins: (left: Int, top: Int, right: Int, bottom: Int)?
        config.onMarginsDivergedDetailed = { l, t, r, b in
            divergedMargins = (l, t, r, b)
        }

        let updated = config.updateDimensions(width: 1620, height: 2160)
        XCTAssertTrue(updated)

        XCTAssertEqual(config.negotiatedWidth, 1920)
        XCTAssertEqual(config.negotiatedHeight, 1080)
        XCTAssertEqual(config.screenWidthPx, 1620)
        XCTAssertEqual(config.screenHeightPx, 2160)

        let (marginW, marginH) = config.getMargins()
        XCTAssertEqual(marginW, 1110, "Width margin should crop 1920 to 810 for 3:4 aspect ratio")
        XCTAssertEqual(marginH, 0, "Height margin should be 0")

        let activeW = 1920 - marginW
        let activeH = 1080 - marginH
        let activeAspect = Double(activeW) / Double(activeH)
        let screenAspect = Double(1620) / Double(2160)
        XCTAssertEqual(activeAspect, screenAspect, accuracy: 0.001, "Active viewport must exactly match screen aspect ratio for 1:1 square pixels")

        XCTAssertNotNil(divergedMargins)
        XCTAssertEqual(divergedMargins?.left, 555)
        XCTAssertEqual(divergedMargins?.right, 555)
        XCTAssertEqual(divergedMargins?.top, 0)
        XCTAssertEqual(divergedMargins?.bottom, 0)
    }

    func testSystemOrientationDensityClamping() {
        let config = HeadUnitScreenConfig.shared
        config.clearCustomNegotiatedResolution()
        let prevOrientation = ProjectionSettings.orientation
        defer { ProjectionSettings.orientation = prevOrientation }

        ProjectionSettings.orientation = .system
        config.negotiatedWidth = 1920
        config.negotiatedHeight = 1080
        _ = config.updateDimensions(width: 1620, height: 2160)

        let density = config.announcedDensity
        XCTAssertLessThanOrEqual(density, 160, "Auto density under system orientation for 1080p must be clamped to <= 160 dpi")

        config.negotiatedWidth = 1280
        config.negotiatedHeight = 720
        let density720 = config.announcedDensity
        XCTAssertLessThanOrEqual(density720, 120, "Auto density under system orientation for 720p must be clamped to <= 120 dpi")

        config.clearCustomNegotiatedResolution()
    }

    func testSystemOrientationSelectsLandscapeBaseCanvasEvenOnPortraitDisplay() {
        let prevOrientation = ProjectionSettings.orientation
        defer {
            ProjectionSettings.orientation = prevOrientation
            HeadUnitScreenConfig.shared.initScreen(width: 1920, height: 1080, requestedResolution: .r1920x1080)
        }

        ProjectionSettings.orientation = .system
        let config = HeadUnitScreenConfig.shared
        config.clearCustomNegotiatedResolution()
        config.initScreen(width: 1640, height: 2360, requestedResolution: .r1920x1080)

        XCTAssertTrue(config.isPortraitDisplay)
        XCTAssertEqual(config.negotiatedResolutionType, ._1920x1080, "Auto (.system) orientation must use landscape base canvas for seamless rotation")

        let (marginW, marginH) = config.getMargins()
        XCTAssertGreaterThan(marginW, 0, "Portrait display under landscape canvas must have dynamic width crop margin")
        XCTAssertEqual(marginH, 0)
    }

    func test2KResolutionServiceDiscoveryResponseAutoPromotesToHevc() throws {
        let prevPref = ProjectionSettings.videoCodecPreference
        defer { ProjectionSettings.videoCodecPreference = prevPref }
        ProjectionSettings.videoCodecPreference = .h264

        let config = HeadUnitScreenConfig.shared
        config.clearCustomNegotiatedResolution()
        config.initScreen(width: 2560, height: 1600, requestedResolution: .r2560x1440)

        let msg = AapServiceDiscoveryResponseMessage.make(
            screenConfig: config,
            requestedDpi: 200,
            enableAudioSink: true
        )

        var reader = ProtoReader(data: msg.payload)
        let proto = try ServiceDiscoveryResponseProto(from: &reader)

        let videoService = proto.services.first(where: { $0.id == UInt32(Channel.ID_VID) })
        XCTAssertNotNil(videoService)

        let configs = videoService?.mediaSinkService?.videoConfigs ?? []
        XCTAssertEqual(configs.count, 1, "2K resolution announces clean single video config")
        XCTAssertEqual(configs[0].codecResolution, ._2560x1440)
        XCTAssertEqual(configs[0].videoCodecType, .mediaCodecVideoH265, "High-res 2K primary config must automatically promote to HEVC")
        XCTAssertEqual(videoService?.mediaSinkService?.availableType, .mediaCodecVideoH265)
    }

    func testH264PSliceDoesNotCollideWithHevcVPS() {
        let h264PSlice = Data([0x41, 0x9A, 0x24, 0x11, 0x00])
        let isHevcFromPSlice = H264VideoRendererView.detectHevc(from: [h264PSlice], preference: .h264)
        XCTAssertFalse(isHevcFromPSlice, "H.264 non-IDR P-slice (0x41) must NEVER be misdetected as HEVC VPS")

        let h264SPS = Data([0x67, 0x42, 0x00, 0x1E])
        let isHevcFromH264SPS = H264VideoRendererView.detectHevc(from: [h264SPS], preference: .hevc)
        XCTAssertFalse(isHevcFromH264SPS, "H.264 SPS (0x67) must immediately identify as H.264 even if preference is HEVC")

        let hevcVPS = Data([0x40, 0x01, 0x0C, 0x01, 0xFF])
        let isHevcFromVPS = H264VideoRendererView.detectHevc(from: [hevcVPS], preference: .h264)
        XCTAssertTrue(isHevcFromVPS, "HEVC VPS (0x40 0x01) must be detected as HEVC even if preference is H.264")

        let hevcSPS = Data([0x42, 0x01, 0x01, 0x01])
        let isHevcFromHevcSPS = H264VideoRendererView.detectHevc(from: [hevcSPS], preference: .h264)
        XCTAssertTrue(isHevcFromHevcSPS, "HEVC SPS (0x42 0x01) must be detected as HEVC")
    }
}
