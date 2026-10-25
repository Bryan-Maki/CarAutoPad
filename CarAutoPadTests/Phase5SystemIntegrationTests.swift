import XCTest
import UIKit
import AVFoundation
@testable import CarAutoPad

final class Phase5SystemIntegrationTests: XCTestCase {

    func testIPadModelFamilyCatalogDetection() {
        let mini = HeadUnitScreenConfig.detectModelFamily(panelW: 2266, panelH: 1488)
        XCTAssertEqual(mini, .ipadMini)
        XCTAssertEqual(mini.displayName, "iPad mini (8.3\")")

        let standard102 = HeadUnitScreenConfig.detectModelFamily(panelW: 2160, panelH: 1620)
        XCTAssertEqual(standard102, .ipadStandard102)

        let air109 = HeadUnitScreenConfig.detectModelFamily(panelW: 2360, panelH: 1640)
        XCTAssertEqual(air109, .ipadAirAndStandard109)

        let pro11 = HeadUnitScreenConfig.detectModelFamily(panelW: 2388, panelH: 1668)
        XCTAssertEqual(pro11, .ipadPro11)

        let pro129 = HeadUnitScreenConfig.detectModelFamily(panelW: 2732, panelH: 2048)
        XCTAssertEqual(pro129, .ipadPro129AndAir13)

        let pro13M4 = HeadUnitScreenConfig.detectModelFamily(panelW: 2752, panelH: 2064)
        XCTAssertEqual(pro13M4, .ipadPro13M4)

        let generic = HeadUnitScreenConfig.detectModelFamily(panelW: 1000, panelH: 800)
        XCTAssertEqual(generic, .genericIpad)
    }

    func testIPadModelCatalogRecommendedDpi() {
        let miniDpi1080 = AnnouncedDensityPolicy.recommendedDpi(activeW: 1440, activeH: 1080, panelW: 2266, panelH: 1488)
        XCTAssertEqual(miniDpi1080, 160)

        let miniDpi1440 = AnnouncedDensityPolicy.recommendedDpi(activeW: 1920, activeH: 1440, panelW: 2266, panelH: 1488)
        XCTAssertEqual(miniDpi1440, 210)

        let stdDpi1080 = AnnouncedDensityPolicy.recommendedDpi(activeW: 1440, activeH: 1080, panelW: 2160, panelH: 1620)
        XCTAssertEqual(stdDpi1080, 170)

        let stdDpi1440 = AnnouncedDensityPolicy.recommendedDpi(activeW: 1920, activeH: 1440, panelW: 2160, panelH: 1620)
        XCTAssertEqual(stdDpi1440, 220)

        let airDpi1080 = AnnouncedDensityPolicy.recommendedDpi(activeW: 1440, activeH: 1080, panelW: 2360, panelH: 1640)
        XCTAssertEqual(airDpi1080, 180)

        let airDpi1440 = AnnouncedDensityPolicy.recommendedDpi(activeW: 1920, activeH: 1440, panelW: 2388, panelH: 1668)
        XCTAssertEqual(airDpi1440, 240)

        let proDpi1080 = AnnouncedDensityPolicy.recommendedDpi(activeW: 1440, activeH: 1080, panelW: 2732, panelH: 2048)
        XCTAssertEqual(proDpi1080, 200)

        let proDpi1440 = AnnouncedDensityPolicy.recommendedDpi(activeW: 1920, activeH: 1440, panelW: 2752, panelH: 2064)
        XCTAssertEqual(proDpi1440, 240)
    }

    func testServiceDiscoveryResponseVideoConfiguration() {
        let config = HeadUnitScreenConfig.shared
        config.initScreen(width: 2160, height: 1620, scale: 2.0, fitMode: .fillMargin, requestedResolution: .r1920x1080)

        let message = AapServiceDiscoveryResponseMessage.make(
            screenConfig: config,
            fpsLimit: 60,
            rightHandDrive: false,
            requestedDpi: 170
        )

        XCTAssertEqual(message.channel, Int(Channel.ID_CTR))
        XCTAssertEqual(message.type, Int(ControlMsgType.messageServiceDiscoveryResponse.rawValue))

        var reader = ProtoReader(data: message.payload)
        guard let proto = try? ServiceDiscoveryResponseProto(from: &reader) else {
            XCTFail("Expected ServiceDiscoveryResponseProto")
            return
        }

        let videoService = proto.services.first(where: { $0.id == UInt32(Channel.ID_VID) })
        XCTAssertNotNil(videoService)
        XCTAssertNotNil(videoService?.mediaSinkService)

        let videoConfig = videoService?.mediaSinkService?.videoConfigs.first
        XCTAssertNotNil(videoConfig)
        XCTAssertEqual(videoConfig?.codecResolution, ._1920x1080)
        XCTAssertNil(videoConfig?.decoderAdditionalDepth, "decoderAdditionalDepth should be nil to match open-headunit")
        XCTAssertEqual(videoConfig?.frameRate, ._60)

        let inputService = proto.services.first(where: { $0.id == UInt32(Channel.ID_INP) })
        XCTAssertNotNil(inputService)
        XCTAssertEqual(inputService?.inputSourceService?.touchscreen?.width, 1920)
        XCTAssertEqual(inputService?.inputSourceService?.touchscreen?.height, 1080)
    }

    func testTouchCoordinateMapperWithMargins() {
        let centerCoord = TouchCoordinateMapper.map(
            rawX: 500,
            rawY: 500,
            inputSurfaceWidth: 1000,
            inputSurfaceHeight: 1000,
            negotiatedWidth: 1920,
            negotiatedHeight: 1080,
            marginWidth: 480,
            marginHeight: 0,
            fitMode: .fillMargin
        )

        XCTAssertEqual(centerCoord.x, 720)
        XCTAssertEqual(centerCoord.y, 540)

        let topLeftCoord = TouchCoordinateMapper.map(
            rawX: 0,
            rawY: 0,
            inputSurfaceWidth: 1000,
            inputSurfaceHeight: 1000,
            negotiatedWidth: 1920,
            negotiatedHeight: 1080,
            marginWidth: 480,
            marginHeight: 0,
            fitMode: .fillMargin
        )

        XCTAssertEqual(topLeftCoord.x, 0)
        XCTAssertEqual(topLeftCoord.y, 0)

        let bottomRightCoord = TouchCoordinateMapper.map(
            rawX: 1000,
            rawY: 1000,
            inputSurfaceWidth: 1000,
            inputSurfaceHeight: 1000,
            negotiatedWidth: 1920,
            negotiatedHeight: 1080,
            marginWidth: 480,
            marginHeight: 0,
            fitMode: .fillMargin
        )

        XCTAssertEqual(bottomRightCoord.x, 1440)
        XCTAssertEqual(bottomRightCoord.y, 1080)
    }

    @MainActor
    func testMainViewControllerFullscreenAndTouchHierarchy() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()

        mainVC.loadViewIfNeeded()
        mainVC.view.layoutIfNeeded()

        XCTAssertFalse(mainVC.prefersStatusBarHidden)
        XCTAssertFalse(mainVC.prefersHomeIndicatorAutoHidden)

        let touchViews = mainVC.view.subviews.flatMap { $0.subviews }.compactMap { $0 as? TouchInputView }
        XCTAssertFalse(touchViews.isEmpty, "TouchInputView should exist in the view hierarchy")
        for touchView in touchViews {
            XCTAssertTrue(touchView.isUserInteractionEnabled)
            XCTAssertTrue(touchView.isMultipleTouchEnabled)
        }
    }

    func testTouchEventEncodingAlwaysWritesZeroFields() {
        let msg = AapTouchEventMessage.make(
            timestampNs: 0,
            action: .down,
            actionIndex: 0,
            pointers: [(id: 0, x: 0, y: 0)]
        )

        let bytes = [UInt8](msg.payload)
        XCTAssertTrue(bytes.starts(with: [0x08, 0x00]), "InputReport must always write timestamp field 1 even when 0")
        XCTAssertTrue(bytes.contains(0x1A), "InputReport must encode touch_event at field 3 (wire tag 0x1A)")

        let expectedPointerBytes: [UInt8] = [0x0A, 0x06, 0x08, 0x00, 0x10, 0x00, 0x18, 0x00]
        XCTAssertNotNil(
            bytes.firstRange(of: expectedPointerBytes),
            "TouchEvent Pointer must explicitly write x=0, y=0, and pointer_id=0 ([0x18, 0x00])"
        )

        let expectedActionTail: [UInt8] = [0x10, 0x00, 0x18, 0x00]
        XCTAssertTrue(
            bytes.suffix(4).elementsEqual(expectedActionTail),
            "TouchEvent must explicitly write action_index=0 ([0x10, 0x00]) and action=0 ([0x18, 0x00])"
        )
    }

    func testMediaAckAlwaysWritesSessionZero() {
        let mediaAck = MediaAck(sessionId: 0, ack: 1)
        let encoded = mediaAck.serializedData()
        let bytes = [UInt8](encoded)

        XCTAssertGreaterThanOrEqual(bytes.count, 4, "MediaAck with sessionId=0 must be at least 4 bytes")
        XCTAssertEqual(Array(bytes.prefix(4)), [0x08, 0x00, 0x10, 0x01], "MediaAck must never omit session=0")

        let defaultAck = MediaAck(sessionId: 0).serializedData()
        XCTAssertEqual([UInt8](defaultAck), [0x08, 0x00, 0x10, 0x01])
    }

    func testPCMAudioPlayerInt16ToFloat32Conversion() {
        let samples: [Int16] = [16384, -16384, 32767, -32768]
        var pcmData = Data(capacity: samples.count * MemoryLayout<Int16>.size)
        for sample in samples {
            var le = sample.littleEndian
            withUnsafeBytes(of: &le) { pcmData.append(contentsOf: $0) }
        }

        let player = PCMAudioPlayer()
        guard let buffer = player.enqueuePCMData(pcmData, sampleRate: 48000, channels: 2) else {
            XCTFail("Expected non-nil Float32 AVAudioPCMBuffer")
            return
        }

        XCTAssertEqual(buffer.format.commonFormat, .pcmFormatFloat32)
        XCTAssertFalse(buffer.format.isInterleaved, "AVAudioPCMBuffer must use standard non-interleaved Float32 format")
        XCTAssertEqual(buffer.format.sampleRate, 48000)
        XCTAssertEqual(buffer.format.channelCount, 2)
        XCTAssertEqual(buffer.frameLength, 2)

        guard let floatChannels = buffer.floatChannelData else {
            XCTFail("Expected non-nil floatChannelData")
            return
        }

        XCTAssertEqual(floatChannels[0][0], 0.5, accuracy: 0.0001)
        XCTAssertEqual(floatChannels[1][0], -0.5, accuracy: 0.0001)

        XCTAssertEqual(floatChannels[0][1], Float(32767.0 / 32768.0), accuracy: 0.0001)
        XCTAssertEqual(floatChannels[1][1], -1.0, accuracy: 0.0001)
    }

    func testSinglePassTouchMappingMatchesActiveVideoRegion() {
        let touchView = TouchInputView(frame: CGRect(x: 0, y: 0, width: 1180, height: 820))
        touchView.surfaceSize = CGSize(width: 1180, height: 820)
        touchView.codecWidth = 1920
        touchView.codecHeight = 1080
        touchView.widthMargin = 480
        touchView.heightMargin = 0
        touchView.videoFitMode = .fillMargin

        let center = touchView.mapTouchToActiveContent(CGPoint(x: 590, y: 410))
        XCTAssertEqual(center.x, 720)
        XCTAssertEqual(center.y, 540)

        let topLeft = touchView.mapTouchToActiveContent(CGPoint(x: 0, y: 0))
        XCTAssertEqual(topLeft.x, 0)
        XCTAssertEqual(topLeft.y, 0)

        let bottomRight = touchView.mapTouchToActiveContent(CGPoint(x: 1180, y: 820))
        XCTAssertEqual(bottomRight.x, 1440)
        XCTAssertEqual(bottomRight.y, 1080)
    }

    func testFragmentedAudioPacketReassemblyDoesNotStripMidStreamBytes() {
        final class TestAudioDelegate: AapTransportDelegate {
            var deliveredAudio: [Data] = []
            func aapTransport(_ transport: AapTransport, didReceiveVideoData data: Data) {}
            func aapTransport(_ transport: AapTransport, didReceiveAudioData data: Data, on channel: UInt8) {
                deliveredAudio.append(data)
            }
            func aapTransport(_ transport: AapTransport, didReceiveAudioData data: Data, on channel: UInt8, isAac: Bool) {
                deliveredAudio.append(data)
            }
            func aapTransport(_ transport: AapTransport, didReceiveAudioCodecConfig data: Data, on channel: UInt8) {}
            func aapTransport(_ transport: AapTransport, didReceiveMediaMetadata metadata: AapMediaMetadata) {}
            func aapTransport(_ transport: AapTransport, didReceivePlaybackStatus status: AapPlaybackStatus) {}
            func aapTransport(_ transport: AapTransport, didRequestMicrophoneCapture isOpen: Bool) {}
            func aapTransport(_ transport: AapTransport, didRequestLocationUpdates isEnabled: Bool) {}
            func aapTransport(_ transport: AapTransport, didChangeState state: AapTransportState) {}
            func aapTransportDidDisconnect(_ transport: AapTransport) {}
            func aapTransportDidRequestExit(_ transport: AapTransport) {}
        }

        final class DummyConnection: ByteStreamConnection {
            weak var delegate: ByteStreamConnectionDelegate?
            var isConnected: Bool = true
            func send(_ data: Data, completion: ((Error?) -> Void)?) { completion?(nil) }
            func disconnect() { isConnected = false }
        }

        let connection = DummyConnection()
        let transport = AapTransport(connection: connection, handshakeProfile: .network)
        let delegate = TestAudioDelegate()
        transport.delegate = delegate

        let channel = Channel.ID_AUD

        var p1 = Data(repeating: 0x00, count: 8)
        p1.append(Data(repeating: 0xAA, count: 100))
        let msg1 = AapMessage(channel: channel, flags: 0x09, type: 0, payload: p1)

        let p2 = Data(repeating: 0xBB, count: 100)
        let msg2 = AapMessage(channel: channel, flags: 0x08, type: 0, payload: p2)

        let p3 = Data(repeating: 0xCC, count: 100)
        let msg3 = AapMessage(channel: channel, flags: 0x0a, type: 0, payload: p3)

        transport.handleMessage(msg1)
        XCTAssertEqual(delegate.deliveredAudio.count, 0, "First fragment should be buffered awaiting complete assembly")

        transport.handleMessage(msg2)
        XCTAssertEqual(delegate.deliveredAudio.count, 0, "Middle fragment should be appended to assembly buffer")

        transport.handleMessage(msg3)
        XCTAssertEqual(delegate.deliveredAudio.count, 1, "Last fragment should trigger delivery of complete audio payload")

        guard let assembled = delegate.deliveredAudio.first else {
            XCTFail("Expected assembled audio data")
            return
        }

        XCTAssertEqual(assembled.count, 300)
        XCTAssertEqual(assembled.prefix(100), Data(repeating: 0xAA, count: 100))
        XCTAssertEqual(assembled.subdata(in: 100..<200), Data(repeating: 0xBB, count: 100))
        XCTAssertEqual(assembled.suffix(100), Data(repeating: 0xCC, count: 100))
    }

    func testNativeVideoFocusRequestTriggersExitToHomeScreen() {
        final class TestExitDelegate: AapTransportDelegate {
            var exitRequested = false
            func aapTransport(_ transport: AapTransport, didReceiveVideoData data: Data) {}
            func aapTransport(_ transport: AapTransport, didReceiveAudioData data: Data, on channel: UInt8) {}
            func aapTransport(_ transport: AapTransport, didReceiveAudioData data: Data, on channel: UInt8, isAac: Bool) {}
            func aapTransport(_ transport: AapTransport, didReceiveAudioCodecConfig data: Data, on channel: UInt8) {}
            func aapTransport(_ transport: AapTransport, didReceiveMediaMetadata metadata: AapMediaMetadata) {}
            func aapTransport(_ transport: AapTransport, didReceivePlaybackStatus status: AapPlaybackStatus) {}
            func aapTransport(_ transport: AapTransport, didRequestMicrophoneCapture isOpen: Bool) {}
            func aapTransport(_ transport: AapTransport, didRequestLocationUpdates isEnabled: Bool) {}
            func aapTransport(_ transport: AapTransport, didChangeState state: AapTransportState) {}
            func aapTransportDidDisconnect(_ transport: AapTransport) {}
            func aapTransportDidRequestExit(_ transport: AapTransport) {
                exitRequested = true
            }
        }

        final class DummyConnection: ByteStreamConnection {
            weak var delegate: ByteStreamConnectionDelegate?
            var isConnected: Bool = true
            func send(_ data: Data, completion: ((Error?) -> Void)?) { completion?(nil) }
            func disconnect() { isConnected = false }
        }

        let connection = DummyConnection()
        let transport = AapTransport(connection: connection, handshakeProfile: .network)
        let delegate = TestExitDelegate()
        transport.delegate = delegate

        var payload = Data()
        payload.append(contentsOf: [0x10, 0x02])
        let msg = AapMessage(channel: Channel.ID_VID, flags: 0, type: 0x8007, payload: payload)

        transport.handleMessage(msg)
        XCTAssertTrue(delegate.exitRequested, "Native video focus request (mode=2) must trigger aapTransportDidRequestExit")
    }

    func testCustomDpiOverridesDefaultModelDpiInServiceDiscovery() {
        let config = HeadUnitScreenConfig.shared
        let prevOrientation = ProjectionSettings.orientation
        defer {
            ProjectionSettings.orientation = prevOrientation
            config.customDpi = nil
            ProjectionSettings.resetDpiToDefault()
        }

        ProjectionSettings.orientation = .landscape
        config.initScreen(width: 2360, height: 1640, scale: 2.0, fitMode: .fillMargin, requestedResolution: .r1920x1080)

        config.customDpi = nil
        ProjectionSettings.isAutoDpi = true
        let defaultDecision = config.densityDecision(requestedDpi: 160)
        XCTAssertEqual(defaultDecision.announced, 180)
        XCTAssertEqual(config.announcedDensity, 180)

        config.customDpi = nil
        ProjectionSettings.isAutoDpi = false
        ProjectionSettings.dpi = 220
        XCTAssertEqual(config.announcedDensity, 220, "announcedDensity must equal 220 when isAutoDpi is false")
        let customDecision = config.densityDecision(requestedDpi: 160)
        XCTAssertEqual(customDecision.announced, 220)

        let message = AapServiceDiscoveryResponseMessage.make(
            screenConfig: config,
            fpsLimit: 60,
            rightHandDrive: false
        )
        var reader = ProtoReader(data: message.payload)
        guard let proto = try? ServiceDiscoveryResponseProto(from: &reader) else {
            XCTFail("Expected ServiceDiscoveryResponseProto")
            return
        }
        let videoService = proto.services.first(where: { $0.id == UInt32(Channel.ID_VID) })
        let videoConfig = videoService?.mediaSinkService?.videoConfigs.first
        XCTAssertEqual(videoConfig?.density, 220, "Video configuration density must equal custom DPI (220)")

        config.customDpi = 240
        XCTAssertEqual(config.announcedDensity, 240)
    }

    func testVideoRendererAndTouchOverlayShareIdenticalMargins() {
        let config = HeadUnitScreenConfig.shared
        config.initScreen(width: 2360, height: 1640, scale: 2.0, fitMode: .fillMargin, requestedResolution: .r1920x1080)

        let renderer = H264VideoRendererView()
        let touchView = TouchInputView()
        touchView.frame = CGRect(x: 0, y: 0, width: 1180, height: 820)
        renderer.frame = CGRect(x: 0, y: 0, width: 1180, height: 820)

        let expectedMarginW = config.getWidthMargin()
        let expectedMarginH = config.getHeightMargin()
        XCTAssertEqual(expectedMarginW, 366, "iPad Air 4 1080p fillMargin width margin must be 366")
        XCTAssertEqual(expectedMarginH, 0)

        config.recordAnnouncedMargins(widthMargin: expectedMarginW, heightMargin: expectedMarginH)

        renderer.codecWidth = config.negotiatedWidth
        renderer.codecHeight = config.negotiatedHeight
        renderer.widthMargin = config.announcedWidthMargin
        renderer.heightMargin = config.announcedHeightMargin
        renderer.fitMode = config.videoFitMode

        touchView.surfaceSize = touchView.bounds.size
        touchView.screenConfig = config
        touchView.videoFitMode = config.videoFitMode
        touchView.codecWidth = config.negotiatedWidth
        touchView.codecHeight = config.negotiatedHeight
        touchView.widthMargin = renderer.widthMargin
        touchView.heightMargin = renderer.heightMargin

        XCTAssertEqual(renderer.widthMargin, touchView.widthMargin)
        XCTAssertEqual(renderer.heightMargin, touchView.heightMargin)
        XCTAssertEqual(renderer.codecWidth, touchView.codecWidth)
        XCTAssertEqual(renderer.codecHeight, touchView.codecHeight)

        let mappedLeft = touchView.mapTouchToActiveContent(CGPoint(x: 0, y: 410))
        XCTAssertEqual(mappedLeft.x, 0, "Left screen tap must map to 0 without halfMargin offset")
        XCTAssertEqual(mappedLeft.y, 540)

        let mappedCenter = touchView.mapTouchToActiveContent(CGPoint(x: 590, y: 410))
        XCTAssertEqual(mappedCenter.x, 777, "Center screen tap must map precisely to active horizontal center 777")
        XCTAssertEqual(mappedCenter.y, 540, "Center screen tap must map precisely to active vertical center 540")

        let mappedRight = touchView.mapTouchToActiveContent(CGPoint(x: 1180, y: 410))
        XCTAssertTrue((1553...1554).contains(mappedRight.x), "Right screen tap must map to active width in [1553, 1554]")
        XCTAssertEqual(mappedRight.y, 540)
    }

    func testVideoMediaAckSentImmediatelyOnFirstFragment() {
        final class MockConnection: ByteStreamConnection {
            weak var delegate: ByteStreamConnectionDelegate?
            var isConnected: Bool = true
            var sentPackets: [Data] = []
            func send(_ data: Data, completion: ((Error?) -> Void)?) {
                sentPackets.append(data)
                completion?(nil)
            }
            func disconnect() { isConnected = false }
        }

        let connection = MockConnection()
        let transport = AapTransport(connection: connection, handshakeProfile: .network)

        let setupMsg = AapMessage(channel: Channel.ID_VID, flags: 0x0b, type: 0x8000, payload: Data())
        transport.handleMessage(setupMsg)

        let configPacket = connection.sentPackets.first { packet in
            guard packet.count >= 6 else { return false }
            let chan = packet[0]
            let type = (Int(packet[4]) << 8) | Int(packet[5])
            return chan == Channel.ID_VID && type == 0x8003
        }
        XCTAssertNotNil(configPacket, "Transport must send Media.Config (0x8003) upon setup")
        if let configPacket = configPacket {
            let payload = configPacket.subdata(in: 6..<configPacket.count)
            let maxUnacked = AapTransport.ProtoWire.extractFirstVarint(from: payload, fieldNumber: 2) ?? 0
            XCTAssertGreaterThanOrEqual(maxUnacked, 12, "Video channel maxUnacked must be >= 12 (configured as 16)")
        }

        connection.sentPackets.removeAll()

        // 1. type == 1 (SPS/PPS config packet) must NOT trigger MediaAck
        let spsPpsMsg = AapMessage(channel: Channel.ID_VID, flags: 0x0b, type: 0x0001, payload: Data([0x00, 0x00, 0x00, 0x01, 0x67, 0x42]))
        transport.handleMessage(spsPpsMsg)
        let ackAfterConfig = connection.sentPackets.first { packet in
            guard packet.count >= 6 else { return false }
            return packet[0] == Channel.ID_VID && ((Int(packet[4]) << 8) | Int(packet[5])) == 0x8004
        }
        XCTAssertNil(ackAfterConfig, "type == 1 config packets must not send MediaAck")

        // 2. Middle fragment (flags: 0x09 first / 0x08 middle) must NOT trigger MediaAck
        var firstFragPayload = Data(repeating: 0x00, count: 8)
        firstFragPayload.append(Data(repeating: 0x12, count: 200))
        let firstFragMsg = AapMessage(channel: Channel.ID_VID, flags: 0x09, type: 0x0000, payload: firstFragPayload)
        transport.handleMessage(firstFragMsg)
        let ackAfterFirstFrag = connection.sentPackets.first { packet in
            guard packet.count >= 6 else { return false }
            return packet[0] == Channel.ID_VID && ((Int(packet[4]) << 8) | Int(packet[5])) == 0x8004
        }
        XCTAssertNil(ackAfterFirstFrag, "Non-final fragments (0x09) must not trigger MediaAck")

        // 3. Final fragment (flags: 0x0a) MUST immediately trigger MediaAck(ack: 1)
        let finalFragMsg = AapMessage(channel: Channel.ID_VID, flags: 0x0a, type: 0x0000, payload: Data(repeating: 0x34, count: 100))
        transport.handleMessage(finalFragMsg)
        let ackPacket = connection.sentPackets.first { packet in
            guard packet.count >= 6 else { return false }
            return packet[0] == Channel.ID_VID && ((Int(packet[4]) << 8) | Int(packet[5])) == 0x8004
        }
        XCTAssertNotNil(ackPacket, "MediaAck (0x8004) must be sent immediately upon final fragment (0x0a)")
        if let ackPacket = ackPacket {
            let payload = ackPacket.subdata(in: 6..<ackPacket.count)
            let ackCount = AapTransport.ProtoWire.extractFirstVarint(from: payload, fieldNumber: 2) ?? 0
            XCTAssertEqual(ackCount, 1, "Per-frame MediaAck should report ack count 1")
        }

        // 4. Single-packet frame (flags: 0x0b) MUST also immediately trigger MediaAck(ack: 1)
        connection.sentPackets.removeAll()
        var singlePacketPayload = Data(repeating: 0x00, count: 8)
        singlePacketPayload.append(Data(repeating: 0x56, count: 300))
        let singlePacketMsg = AapMessage(channel: Channel.ID_VID, flags: 0x0b, type: 0x0000, payload: singlePacketPayload)
        transport.handleMessage(singlePacketMsg)
        let singleAckPacket = connection.sentPackets.first { packet in
            guard packet.count >= 6 else { return false }
            return packet[0] == Channel.ID_VID && ((Int(packet[4]) << 8) | Int(packet[5])) == 0x8004
        }
        XCTAssertNotNil(singleAckPacket, "MediaAck (0x8004) must be sent immediately upon single-packet frame (0x0b)")
        if let singleAckPacket = singleAckPacket {
            let payload = singleAckPacket.subdata(in: 6..<singleAckPacket.count)
            let ackCount = AapTransport.ProtoWire.extractFirstVarint(from: payload, fieldNumber: 2) ?? 0
            XCTAssertEqual(ackCount, 1, "Single-packet MediaAck should report ack count 1")
        }
    }

    func testNightModeSensorStartRequestSendsImmediateNightEventAndLiveUpdate() {
        let prevNight = ProjectionSettings.nightMode
        defer { ProjectionSettings.nightMode = prevNight }

        XCTAssertEqual(NightModeSetting.allCases.count, 5, "NightModeSetting has 5 modes: auto, twilight, day, night, system")

        ProjectionSettings.nightMode = .night
        XCTAssertTrue(ProjectionSettings.effectiveIsNightMode())

        ProjectionSettings.nightMode = .day
        XCTAssertFalse(ProjectionSettings.effectiveIsNightMode())

        ProjectionSettings.nightMode = .system
        XCTAssertTrue(ProjectionSettings.effectiveIsNightMode(userInterfaceStyle: .dark))
        XCTAssertFalse(ProjectionSettings.effectiveIsNightMode(userInterfaceStyle: .light))

        ProjectionSettings.nightMode = .auto
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let expectedAutoNight = (hour < 7 || hour >= 19)
        XCTAssertEqual(ProjectionSettings.effectiveIsNightMode(), expectedAutoNight)

        final class MockConnection: ByteStreamConnection {
            weak var delegate: ByteStreamConnectionDelegate?
            var isConnected: Bool = true
            var sentPackets: [Data] = []
            func send(_ data: Data, completion: ((Error?) -> Void)?) {
                sentPackets.append(data)
                completion?(nil)
            }
            func disconnect() { isConnected = false }
        }

        let connection = MockConnection()
        let transport = AapTransport(connection: connection, handshakeProfile: .network)

        let openMsg = AapMessage(channel: Channel.ID_SEN, flags: 0x03, type: AapMessageType.CHANNEL_OPEN_REQUEST.rawValue, payload: Data([0x08, 0x01]))
        transport.handleMessage(openMsg)

        let sensor10Req = AapMessage(channel: Channel.ID_SEN, flags: 0x03, type: 0x8001, payload: Data([0x08, 0x0a]))
        transport.handleMessage(sensor10Req)

        let exp = expectation(description: "Wait for processingQueue async night mode event")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        let hasStartResponse = connection.sentPackets.contains { packet in
            guard packet.count >= 6 else { return false }
            let chan = packet[0]
            let type = (Int(packet[4]) << 8) | Int(packet[5])
            return chan == Channel.ID_SEN && type == 0x8002
        }
        XCTAssertTrue(hasStartResponse, "Must send Sensor Start Response (0x8002) for sensor 10")

        let hasNightEvent = connection.sentPackets.contains { packet in
            guard packet.count >= 6 else { return false }
            let chan = packet[0]
            let type = (Int(packet[4]) << 8) | Int(packet[5])
            return chan == Channel.ID_SEN && type == 0x8003
        }
        XCTAssertTrue(hasNightEvent, "Must send NightMode SensorEventIndication (0x8003) upon sensor 10 start")
    }

    func testResolutionLockedPreventsDimensionResetDuringRotation() {
        let config = HeadUnitScreenConfig.shared
        config.negotiatedWidth = 1920
        config.negotiatedHeight = 1080
        config.isResolutionLocked = true

        _ = config.updateDimensions(width: 1620, height: 2160)

        XCTAssertEqual(config.negotiatedWidth, 1920)
        XCTAssertEqual(config.negotiatedHeight, 1080)
        XCTAssertEqual(config.screenWidthPx, 1620)
        XCTAssertEqual(config.screenHeightPx, 2160)

        config.clearCustomNegotiatedResolution()
        XCTAssertFalse(config.isResolutionLocked)
    }

    func testNightModeDeduplicationAndForceFlag() {
        final class MockByteConnection: ByteStreamConnection {
            weak var delegate: ByteStreamConnectionDelegate?
            var isConnected: Bool = true
            var sentPackets: [Data] = []
            func send(_ data: Data, completion: ((Error?) -> Void)?) {
                sentPackets.append(data)
                completion?(nil)
            }
            func disconnect() { isConnected = false }
        }

        let connection = MockByteConnection()
        let transport = AapTransport(connection: connection, handshakeProfile: .network)

        let openMsg = AapMessage(channel: Channel.ID_SEN, flags: 0x03, type: AapMessageType.CHANNEL_OPEN_REQUEST.rawValue, payload: Data([0x08, 0x01]))
        transport.handleMessage(openMsg)

        let sensor10Req = AapMessage(channel: Channel.ID_SEN, flags: 0x03, type: 0x8001, payload: Data([0x08, 0x0a]))
        transport.handleMessage(sensor10Req)

        let exp1 = expectation(description: "initial night event")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)

        let initialCount = connection.sentPackets.count
        XCTAssertGreaterThanOrEqual(initialCount, 2, "Sensor start response + initial night mode event must be sent")

        let currentNight = ProjectionSettings.effectiveIsNightMode()
        transport.sendNightModeEvent(isNight: currentNight, force: false)
        let exp2 = expectation(description: "dedup night event")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp2.fulfill() }
        wait(for: [exp2], timeout: 1.0)
        XCTAssertEqual(connection.sentPackets.count, initialCount, "Duplicate night mode event must be suppressed")

        transport.sendNightModeEvent(isNight: currentNight, force: true)
        let exp3 = expectation(description: "forced night event")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp3.fulfill() }
        wait(for: [exp3], timeout: 1.0)
        XCTAssertEqual(connection.sentPackets.count, initialCount + 1, "Forced night mode event must be transmitted")

        transport.sendNightModeEvent(isNight: !currentNight, force: false)
        let exp4 = expectation(description: "different night event")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp4.fulfill() }
        wait(for: [exp4], timeout: 1.0)
        XCTAssertEqual(connection.sentPackets.count, initialCount + 2, "Different night mode value must be transmitted")
    }

    func testDefaultSettingsValues() {
        XCTAssertEqual(ProjectionOrientation.system.title, "Auto")
    }
}
