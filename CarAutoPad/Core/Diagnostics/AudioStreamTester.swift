import Foundation

public final class AudioStreamTester {
    public static let shared = AudioStreamTester()

    public init() {}

    public static func generateSineWavePCM(
        sampleRate: Int,
        channelCount: Int,
        frequencyHz: Double,
        durationSeconds: Double,
        rampSeconds: Double = 0.02
    ) -> Data {
        guard sampleRate > 0, channelCount > 0, durationSeconds > 0 else { return Data() }

        let totalFrames = Int(Double(sampleRate) * durationSeconds)
        let rampFrames = max(1, Int(Double(sampleRate) * rampSeconds))
        let amplitude: Double = 32767.0 * 0.70

        var data = Data(capacity: totalFrames * channelCount * 2)

        for i in 0..<totalFrames {
            let envelope: Double
            if i < rampFrames {
                envelope = Double(i) / Double(rampFrames)
            } else if i >= totalFrames - rampFrames {
                envelope = Double(totalFrames - 1 - i) / Double(rampFrames)
            } else {
                envelope = 1.0
            }

            let phase = 2.0 * .pi * frequencyHz * Double(i) / Double(sampleRate)
            let sampleVal = Int16(clamping: Int((sin(phase) * amplitude * envelope).rounded()))

            for _ in 0..<channelCount {
                var leSample = sampleVal.littleEndian
                withUnsafeBytes(of: &leSample) { bytes in
                    data.append(contentsOf: bytes)
                }
            }
        }

        return data
    }

    public func playMediaTestTone() {
        let vol = Int((ProjectionSettings.mediaVolume * 100).rounded())
        let enabled = ProjectionSettings.isMediaChannelEnabled ? "enabled" : "disabled"
        AudioDiagnostics.shared.record("AudioStreamTester: Playing 440Hz Media test tone (48kHz stereo, 1.0s, vol=\(vol)%, \(enabled))")
        let data = Self.generateSineWavePCM(
            sampleRate: 48000,
            channelCount: 2,
            frequencyHz: 440.0,
            durationSeconds: 1.0
        )
        PCMAudioPlayer.shared.playPCM(data, on: Channel.ID_AUD)
    }

    public func playGuidanceTestTone() {
        let vol = Int((ProjectionSettings.navigationVolume * 100).rounded())
        let enabled = ProjectionSettings.isNavigationChannelEnabled ? "enabled" : "disabled"
        AudioDiagnostics.shared.record("AudioStreamTester: Playing 587Hz Guidance test tone (16kHz mono, 1.0s, vol=\(vol)%, \(enabled))")
        let data = Self.generateSineWavePCM(
            sampleRate: 16000,
            channelCount: 1,
            frequencyHz: 587.33,
            durationSeconds: 1.0
        )
        PCMAudioPlayer.shared.playPCM(data, on: Channel.ID_GUD)
    }

    public func playSystemTestTone() {
        let vol = Int((ProjectionSettings.phoneSystemVolume * 100).rounded())
        let enabled = ProjectionSettings.isSystemChannelEnabled ? "enabled" : "disabled"
        AudioDiagnostics.shared.record("AudioStreamTester: Playing 880Hz System test tone (16kHz mono, 0.8s, vol=\(vol)%, \(enabled))")
        let data = Self.generateSineWavePCM(
            sampleRate: 16000,
            channelCount: 1,
            frequencyHz: 880.0,
            durationSeconds: 0.8
        )
        PCMAudioPlayer.shared.playPCM(data, on: Channel.ID_SYS)
    }

    public func playDuckingTestSequence() {
        let duckPct = Int((ProjectionSettings.navigationDuckingAmount * 100).rounded())
        let medVol = Int((ProjectionSettings.mediaVolume * 100).rounded())
        let navVol = Int((ProjectionSettings.navigationVolume * 100).rounded())
        AudioDiagnostics.shared.record("AudioStreamTester: Starting ducking test sequence (Media=\(medVol)%, Nav=\(navVol)%, Ducking=-\(duckPct)%)")
        let mediaData = Self.generateSineWavePCM(
            sampleRate: 48000,
            channelCount: 2,
            frequencyHz: 440.0,
            durationSeconds: 2.5
        )
        PCMAudioPlayer.shared.playPCM(mediaData, on: Channel.ID_AUD)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            AudioDiagnostics.shared.record("AudioStreamTester: Overlaying Guidance speech tone (triggering ducking -\(duckPct)%)")
            let guidanceData = Self.generateSineWavePCM(
                sampleRate: 16000,
                channelCount: 1,
                frequencyHz: 880.0,
                durationSeconds: 1.0
            )
            PCMAudioPlayer.shared.noteSpeechActivity()
            PCMAudioPlayer.shared.playPCM(guidanceData, on: Channel.ID_GUD)
        }
    }
}
