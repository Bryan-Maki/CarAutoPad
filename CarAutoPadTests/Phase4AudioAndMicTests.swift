import XCTest
import Foundation
@testable import CarAutoPad

final class Phase4AudioAndMicTests: XCTestCase {

    func testAacCodecConfigDefaultGenerationAndParsing() {
        let csd48kStereo = AacCodecConfig.defaultConfig(sampleRate: 48000, channels: 2)
        XCTAssertEqual(csd48kStereo.count, 2)
        XCTAssertEqual(csd48kStereo[0], 0x11)
        XCTAssertEqual(csd48kStereo[1], 0x90)

        let parsed48k = AacCodecConfig.parse(csd: csd48kStereo)
        XCTAssertNotNil(parsed48k)
        XCTAssertEqual(parsed48k?.sampleRate, 48000)
        XCTAssertEqual(parsed48k?.channels, 2)
        XCTAssertEqual(parsed48k?.audioObjectType, 2)

        let csd16kMono = AacCodecConfig.defaultConfig(sampleRate: 16000, channels: 1)
        let parsed16k = AacCodecConfig.parse(csd: csd16kMono)
        XCTAssertNotNil(parsed16k)
        XCTAssertEqual(parsed16k?.sampleRate, 16000)
        XCTAssertEqual(parsed16k?.channels, 1)
    }

    func testAacCodecConfigInvalidAsc() {
        let empty = Data()
        XCTAssertNil(AacCodecConfig.parse(csd: empty))

        let singleByte = Data([0x11])
        XCTAssertNil(AacCodecConfig.parse(csd: singleByte))
    }

    func testAudioSinkCodecPolicyMapping() {
        XCTAssertEqual(AudioSinkCodecPolicy.codec(forWireValue: 0), .pcm)
        XCTAssertEqual(AudioSinkCodecPolicy.codec(forWireValue: 1), .aacLc)
        XCTAssertEqual(AudioSinkCodecPolicy.codec(forWireValue: 2), .aacLcAdts)
        XCTAssertEqual(AudioSinkCodecPolicy.codec(forWireValue: 99), .pcm)

        XCTAssertEqual(AudioSinkCodecPolicy.wireValue(forCodec: .pcm), 0)
        XCTAssertEqual(AudioSinkCodecPolicy.wireValue(forCodec: .aacLc), 1)
        XCTAssertEqual(AudioSinkCodecPolicy.wireValue(forCodec: .aacLcAdts), 2)
    }

    func testAudioSinkAnnouncementPolicy() {
        let policy = AudioSinkAnnouncementPolicy()

        let aacCodecs = policy.supportedCodecs(for: .aac, channel: 3)
        XCTAssertTrue(aacCodecs.contains(.aacLc))
        XCTAssertTrue(aacCodecs.contains(.aacLcAdts))

        let pcmCodecs = policy.supportedCodecs(for: .pcm, channel: 3)
        XCTAssertEqual(pcmCodecs, [.pcm])
    }

    func testMixerDuckingEnvelopeTransitions() {
        let duck = MixerDuckingEnvelope(sampleRate: 48000, attackMs: 10, releaseMs: 20, duckedGain: 0.3)
        XCTAssertEqual(duck.currentGain, 1.0, accuracy: 0.001)

        duck.setSpeechActive(true)

        let buffer1 = [Float](repeating: 1.0, count: 240)
        let ducked1 = duck.process(samples: buffer1, channels: 1)
        XCTAssertEqual(ducked1.count, 240)
        XCTAssertLessThan(ducked1.last!, 1.0)
        XCTAssertGreaterThan(ducked1.last!, 0.3)

        let buffer2 = [Float](repeating: 1.0, count: 480)
        let ducked2 = duck.process(samples: buffer2, channels: 1)
        XCTAssertEqual(ducked2.last!, 0.3, accuracy: 0.01)

        duck.setSpeechActive(false)
        let buffer3 = [Float](repeating: 1.0, count: 48000)
        let ducked3 = duck.process(samples: buffer3, channels: 1)
        XCTAssertEqual(ducked3.last!, 1.0, accuracy: 0.001)
    }

    func testMicPcmDecimator48kTo16kDecimation() {
        let decimator = MicPcmDecimator()

        let inputSamples: [Int16] = (0..<48).map { Int16($0 * 100) }
        let outputSamples = decimator.decimate(samples: inputSamples)

        XCTAssertEqual(outputSamples.count, 16)

        let chunk1: [Int16] = [Int16](repeating: 1000, count: 10)
        let out1 = decimator.decimate(samples: chunk1)
        XCTAssertEqual(out1.count, 3)

        let chunk2: [Int16] = [Int16](repeating: 1000, count: 11)
        let out2 = decimator.decimate(samples: chunk2)
        XCTAssertEqual(out2.count, 4)
    }

    func testMicChunkAccumulatorFixedSizeEmission() {
        let accumulator = MicChunkAccumulator(targetChunkSamples: 2048)

        let samples1 = [Int16](repeating: 100, count: 1000)
        let emitted1 = accumulator.append(samples: samples1)
        XCTAssertTrue(emitted1.isEmpty)

        let samples2 = [Int16](repeating: 200, count: 1500)
        let emitted2 = accumulator.append(samples: samples2)
        XCTAssertEqual(emitted2.count, 1)
        XCTAssertEqual(emitted2[0].count, 2048)
        XCTAssertEqual(accumulator.pendingSampleCount, 452)
    }

    func testAudioOutputTargetPhoneOmitsMediaAndSpeechSinksButKeepsSystemSink() {
        XCTAssertTrue(AudioOutputTarget.ipad.isAudioSinkEnabled)
        XCTAssertFalse(AudioOutputTarget.phone.isAudioSinkEnabled)
        XCTAssertEqual(AudioOutputTarget.ipad.title, "iPad (Speaker / iPad BT)")
        XCTAssertEqual(AudioOutputTarget.phone.title, "Phone (Original Device)")

        XCTAssertTrue(AudioSinkAnnouncementPolicy.announcesMediaAndSpeech(sinkEnabled: true))
        XCTAssertFalse(AudioSinkAnnouncementPolicy.announcesMediaAndSpeech(sinkEnabled: false))

        let phoneMsg = AapServiceDiscoveryResponseMessage.make(enableAudioSink: false)
        var readerPhone = ProtoReader(data: phoneMsg.payload)
        guard let phoneProto = try? ServiceDiscoveryResponseProto(from: &readerPhone) else {
            XCTFail("Failed to parse ServiceDiscoveryResponseProto")
            return
        }
        let phoneChannelIds = phoneProto.services.map { $0.id }
        XCTAssertTrue(phoneChannelIds.contains(UInt32(Channel.ID_AU2)), "System audio sink must always be announced")
        XCTAssertFalse(phoneChannelIds.contains(UInt32(Channel.ID_AUD)), "Media sink must NOT be announced when enableAudioSink is false")
        XCTAssertFalse(phoneChannelIds.contains(UInt32(Channel.ID_AU1)), "Speech sink must NOT be announced when enableAudioSink is false")

        let ipadMsg = AapServiceDiscoveryResponseMessage.make(enableAudioSink: true)
        var readerIpad = ProtoReader(data: ipadMsg.payload)
        guard let ipadProto = try? ServiceDiscoveryResponseProto(from: &readerIpad) else {
            XCTFail("Failed to parse ServiceDiscoveryResponseProto")
            return
        }
        let ipadChannelIds = ipadProto.services.map { $0.id }
        XCTAssertTrue(ipadChannelIds.contains(UInt32(Channel.ID_AU2)), "System audio sink must be announced")
        XCTAssertTrue(ipadChannelIds.contains(UInt32(Channel.ID_AUD)), "Media sink must be announced when enableAudioSink is true")
        XCTAssertTrue(ipadChannelIds.contains(UInt32(Channel.ID_AU1)), "Speech sink must be announced when enableAudioSink is true")
    }

    func testPCMAudioPlayerRouteRebuildResetsStreamsCleanly() {
        let player = PCMAudioPlayer()
        player.reset()
        XCTAssertEqual(player.streamCount, 0)
        XCTAssertNil(player.isPrebuffering(channel: Channel.ID_AUD))

        player.rebuildEngineAndStreams(reason: "unit-test-route-change")
        XCTAssertEqual(player.streamCount, 0)

        player.stop()
        XCTAssertEqual(player.streamCount, 0)
    }
}
