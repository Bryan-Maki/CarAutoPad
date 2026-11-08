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


    func testChannelVolumesAndTogglesDefaultsAndClamping() {
        ProjectionSettings.resetToDefaults()
        XCTAssertEqual(ProjectionSettings.mediaVolume, 1.0)
        XCTAssertEqual(ProjectionSettings.navigationVolume, 1.0)
        XCTAssertEqual(ProjectionSettings.phoneSystemVolume, 1.0)
        XCTAssertTrue(ProjectionSettings.isMediaChannelEnabled)
        XCTAssertTrue(ProjectionSettings.isNavigationChannelEnabled)
        XCTAssertTrue(ProjectionSettings.isSystemChannelEnabled)
        XCTAssertEqual(ProjectionSettings.navigationDuckingAmount, 0.70, accuracy: 0.001)

        XCTAssertEqual(ProjectionSettings.audioChannelsSummaryText, "iPad (100%/100%/100% • Duck -70%)")

        ProjectionSettings.audioOutputTarget = .phone
        XCTAssertEqual(ProjectionSettings.audioChannelsSummaryText, "Phone (Original Device)")
        ProjectionSettings.audioOutputTarget = .ipad

        // Test clamping
        ProjectionSettings.mediaVolume = -0.5
        XCTAssertEqual(ProjectionSettings.mediaVolume, 0.0)
        ProjectionSettings.mediaVolume = 1.8
        XCTAssertEqual(ProjectionSettings.mediaVolume, 1.0)

        ProjectionSettings.navigationVolume = -0.1
        XCTAssertEqual(ProjectionSettings.navigationVolume, 0.0)
        ProjectionSettings.navigationVolume = 1.1
        XCTAssertEqual(ProjectionSettings.navigationVolume, 1.0)

        ProjectionSettings.phoneSystemVolume = -0.3
        XCTAssertEqual(ProjectionSettings.phoneSystemVolume, 0.0)
        ProjectionSettings.phoneSystemVolume = 1.3
        XCTAssertEqual(ProjectionSettings.phoneSystemVolume, 1.0)

        ProjectionSettings.navigationDuckingAmount = -0.2
        XCTAssertEqual(ProjectionSettings.navigationDuckingAmount, 0.0)
        ProjectionSettings.navigationDuckingAmount = 1.5
        XCTAssertEqual(ProjectionSettings.navigationDuckingAmount, 1.0)

        // Summary text tests
        ProjectionSettings.mediaVolume = 0.8
        ProjectionSettings.navigationVolume = 0.5
        ProjectionSettings.phoneSystemVolume = 1.0
        ProjectionSettings.navigationDuckingAmount = 0.0
        XCTAssertTrue(ProjectionSettings.audioChannelsSummaryText.contains("No Duck"))
        XCTAssertTrue(ProjectionSettings.audioChannelsSummaryText.contains("80%/50%/100%"))

        ProjectionSettings.isMediaChannelEnabled = false
        XCTAssertTrue(ProjectionSettings.audioChannelsSummaryText.contains("Off/50%/100%"))

        ProjectionSettings.resetToDefaults()
        XCTAssertEqual(ProjectionSettings.mediaVolume, 1.0)
        XCTAssertEqual(ProjectionSettings.navigationDuckingAmount, 0.70, accuracy: 0.001)
    }

    func testNavigationDuckingPresetProperties() {
        XCTAssertEqual(NavigationDuckingPreset.off.rawValue, 0)
        XCTAssertEqual(NavigationDuckingPreset.off.dropPercentage, 0)
        XCTAssertEqual(NavigationDuckingPreset.off.reductionAmount, 0.0, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.off.retainedGain, 1.0, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.off.shortTitle, "Off (0%)")

        XCTAssertEqual(NavigationDuckingPreset.light.rawValue, 25)
        XCTAssertEqual(NavigationDuckingPreset.light.dropPercentage, 25)
        XCTAssertEqual(NavigationDuckingPreset.light.reductionAmount, 0.25, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.light.retainedGain, 0.75, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.light.shortTitle, "-25%")

        XCTAssertEqual(NavigationDuckingPreset.medium.rawValue, 50)
        XCTAssertEqual(NavigationDuckingPreset.medium.dropPercentage, 50)
        XCTAssertEqual(NavigationDuckingPreset.medium.reductionAmount, 0.50, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.medium.retainedGain, 0.50, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.medium.shortTitle, "-50%")

        XCTAssertEqual(NavigationDuckingPreset.standard.rawValue, 70)
        XCTAssertEqual(NavigationDuckingPreset.standard.dropPercentage, 70)
        XCTAssertEqual(NavigationDuckingPreset.standard.reductionAmount, 0.70, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.standard.retainedGain, 0.30, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.standard.shortTitle, "-70%")

        XCTAssertEqual(NavigationDuckingPreset.deep.rawValue, 85)
        XCTAssertEqual(NavigationDuckingPreset.deep.dropPercentage, 85)
        XCTAssertEqual(NavigationDuckingPreset.deep.reductionAmount, 0.85, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.deep.retainedGain, 0.15, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.deep.shortTitle, "-85%")

        XCTAssertEqual(NavigationDuckingPreset.mute.rawValue, 100)
        XCTAssertEqual(NavigationDuckingPreset.mute.dropPercentage, 100)
        XCTAssertEqual(NavigationDuckingPreset.mute.reductionAmount, 1.0, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.mute.retainedGain, 0.0, accuracy: 0.001)
        XCTAssertEqual(NavigationDuckingPreset.mute.shortTitle, "-100%")
    }

    func testSettingsBackupManagerAudioVolumesAndDucking() throws {
        ProjectionSettings.resetToDefaults()

        ProjectionSettings.mediaVolume = 0.75
        ProjectionSettings.navigationVolume = 0.60
        ProjectionSettings.phoneSystemVolume = 0.45
        ProjectionSettings.isMediaChannelEnabled = true
        ProjectionSettings.isNavigationChannelEnabled = false
        ProjectionSettings.isSystemChannelEnabled = true
        ProjectionSettings.navigationDuckingAmount = 0.85

        let json = SettingsBackupManager.exportToJson()
        XCTAssertTrue(json.contains("\"mediaVolume\""))
        XCTAssertTrue(json.contains("\"navigationDuckingAmount\""))
        XCTAssertTrue(json.contains("\"isNavigationChannelEnabled\" : false"))

        ProjectionSettings.resetToDefaults()
        XCTAssertEqual(ProjectionSettings.mediaVolume, 1.0)
        XCTAssertTrue(ProjectionSettings.isNavigationChannelEnabled)

        try SettingsBackupManager.importFromJson(json)
        XCTAssertEqual(ProjectionSettings.mediaVolume, 0.75, accuracy: 0.01)
        XCTAssertEqual(ProjectionSettings.navigationVolume, 0.60, accuracy: 0.01)
        XCTAssertEqual(ProjectionSettings.phoneSystemVolume, 0.45, accuracy: 0.01)
        XCTAssertFalse(ProjectionSettings.isNavigationChannelEnabled)
        XCTAssertEqual(ProjectionSettings.navigationDuckingAmount, 0.85, accuracy: 0.01)

        // Test backward compatibility with json lacking audio fields
        let v1Json = """
        {
          "format" : "carautopad-settings",
          "version" : 1,
          "exportedAt" : "2026-11-01T00:00:00Z",
          "settings" : {
            "resolution" : 0,
            "fpsLimit" : 60,
            "dpi" : 160,
            "fitMode" : 0,
            "rightHandDrive" : false,
            "gpsSource" : 0,
            "orientation" : 0,
            "autoReconnect" : true,
            "autoResumePlayback" : true,
            "videoCodecPreference" : "H264",
            "audioCodecPreference" : 1,
            "audioOutputTarget" : 0,
            "nightMode" : 0,
            "showPerformanceOverlay" : false
          }
        }
        """
        XCTAssertNoThrow(try SettingsBackupManager.importFromJson(v1Json))

        ProjectionSettings.resetToDefaults()
    }

    func testMixerDuckingEnvelopeUpdateGainAndClamping() {
        let envelope = MixerDuckingEnvelope(sampleRate: 48000, duckedGain: 1.5)
        XCTAssertEqual(envelope.duckedGain, 1.0, accuracy: 0.001)

        envelope.updateDuckedGain(-0.5, isSpeechActive: false)
        XCTAssertEqual(envelope.duckedGain, 0.0, accuracy: 0.001)

        envelope.updateDuckedGain(0.35, isSpeechActive: false)
        XCTAssertEqual(envelope.duckedGain, 0.35, accuracy: 0.001)

        envelope.setSpeechActive(true)
        envelope.updateDuckedGain(0.20, isSpeechActive: true)
        XCTAssertEqual(envelope.duckedGain, 0.20, accuracy: 0.001)
        XCTAssertEqual(envelope.currentGain, 0.20, accuracy: 0.001)
    }

    func testPCMAudioPlayerComputeEffectiveVolumesAndDucking() {
        ProjectionSettings.resetToDefaults()
        ProjectionSettings.mediaVolume = 0.8
        ProjectionSettings.navigationVolume = 0.5
        ProjectionSettings.phoneSystemVolume = 0.3
        ProjectionSettings.navigationDuckingAmount = 0.70

        // 1. When speech is inactive: no ducking, media is at base volume
        let inactiveVolumes = PCMAudioPlayer.computeEffectiveVolumes(isSpeechActive: false)
        XCTAssertEqual(inactiveVolumes.media, 0.8, accuracy: 0.001)
        XCTAssertEqual(inactiveVolumes.navigation, 0.5, accuracy: 0.001)
        XCTAssertEqual(inactiveVolumes.system, 0.3, accuracy: 0.001)
        XCTAssertFalse(inactiveVolumes.effectiveDucked)

        // 2. When speech is active: media is ducked by 70% (retains 30% -> 0.8 * 0.3 = 0.24)
        let activeVolumes = PCMAudioPlayer.computeEffectiveVolumes(isSpeechActive: true)
        XCTAssertEqual(activeVolumes.media, 0.8 * 0.30, accuracy: 0.001)
        XCTAssertEqual(activeVolumes.navigation, 0.5, accuracy: 0.001)
        XCTAssertEqual(activeVolumes.system, 0.3, accuracy: 0.001)
        XCTAssertTrue(activeVolumes.effectiveDucked)

        // 3. When navigation and system channels are disabled: no ducking should occur even if speech is active
        ProjectionSettings.isNavigationChannelEnabled = false
        ProjectionSettings.isSystemChannelEnabled = false
        let disabledVolumes = PCMAudioPlayer.computeEffectiveVolumes(isSpeechActive: true)
        XCTAssertEqual(disabledVolumes.media, 0.8, accuracy: 0.001)
        XCTAssertEqual(disabledVolumes.navigation, 0.0)
        XCTAssertEqual(disabledVolumes.system, 0.0)
        XCTAssertFalse(disabledVolumes.effectiveDucked)

        // 4. When media channel is disabled: media volume is 0.0
        ProjectionSettings.isMediaChannelEnabled = false
        let mediaOffVolumes = PCMAudioPlayer.computeEffectiveVolumes(isSpeechActive: false)
        XCTAssertEqual(mediaOffVolumes.media, 0.0)

        // 5. Test 100% ducking (mute media)
        ProjectionSettings.isMediaChannelEnabled = true
        ProjectionSettings.isNavigationChannelEnabled = true
        ProjectionSettings.navigationDuckingAmount = 1.0
        let mutedDucking = PCMAudioPlayer.computeEffectiveVolumes(isSpeechActive: true)
        XCTAssertEqual(mutedDucking.media, 0.0, accuracy: 0.001)
        XCTAssertTrue(mutedDucking.effectiveDucked)

        // 6. Test 0% ducking (no ducking)
        ProjectionSettings.navigationDuckingAmount = 0.0
        let noDucking = PCMAudioPlayer.computeEffectiveVolumes(isSpeechActive: true)
        XCTAssertEqual(noDucking.media, 0.8, accuracy: 0.001)
        XCTAssertTrue(noDucking.effectiveDucked)

        ProjectionSettings.resetToDefaults()
    }
}
