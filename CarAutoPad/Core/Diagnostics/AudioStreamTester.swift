import Foundation
import AVFoundation

public final class AudioStreamTester {
    public static let shared = AudioStreamTester()

    public init() {}

    public enum SampleAsset: CaseIterable {
        case media
        case navigation
        case system

        public var filename: String {
            switch self {
            case .media: return "podcast-music-intro-sample"
            case .navigation: return "Route-sample"
            case .system: return "phone-ringing-sample"
            }
        }

        public var fileExtension: String {
            switch self {
            case .media, .system: return "mp3"
            case .navigation: return "wav"
            }
        }

        public var targetSampleRate: Int {
            switch self {
            case .media: return 48000
            case .navigation, .system: return 16000
            }
        }

        public var targetChannels: Int {
            switch self {
            case .media: return 2
            case .navigation, .system: return 1
            }
        }

        public var channelId: UInt8 {
            switch self {
            case .media: return Channel.ID_AUD
            case .navigation: return Channel.ID_AU1
            case .system: return Channel.ID_AU2
            }
        }

        public var fallbackFrequency: Double {
            switch self {
            case .media: return 440.0
            case .navigation: return 587.33
            case .system: return 880.0
            }
        }
    }

    private var sampleCache: [String: Data] = [:]
    private let cacheLock = NSLock()

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

    public static func locateResourceURL(name: String, ext: String) -> URL? {
        let cleanExt = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
        let cleanName = name.hasSuffix("." + cleanExt) ? String(name.dropLast(cleanExt.count + 1)) : name

        var bundles = [Bundle.main, Bundle(for: AudioStreamTester.self)]
        for b in Bundle.allBundles where !bundles.contains(b) {
            bundles.append(b)
        }
        let subpaths: [String?] = [nil, "Audio", "Resources/Audio", "Resources"]
        for bundle in bundles {
            for subpath in subpaths {
                if let url = bundle.url(forResource: cleanName, withExtension: cleanExt, subdirectory: subpath) {
                    return url
                }
            }
            if let url = bundle.url(forResource: cleanName, withExtension: cleanExt) {
                return url
            }
        }
        return nil
    }

    public static func decodeAudioFileToInt16PCM(
        url: URL,
        targetSampleRate: Int,
        targetChannels: Int,
        maxDurationSeconds: Double? = nil
    ) -> Data? {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return nil }
        let srcFormat = audioFile.processingFormat
        guard let dstFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(targetSampleRate),
            channels: AVAudioChannelCount(targetChannels),
            interleaved: false
        ) else { return nil }

        guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else { return nil }

        let totalSrcFrames = audioFile.length
        let maxSrcFrames: AVAudioFramePosition
        if let maxDur = maxDurationSeconds, maxDur > 0 {
            maxSrcFrames = min(totalSrcFrames, AVAudioFramePosition(maxDur * srcFormat.sampleRate))
        } else {
            maxSrcFrames = totalSrcFrames
        }

        let ratio = Double(targetSampleRate) / max(srcFormat.sampleRate, 1.0)
        let estimatedDstFrames = Int(Double(maxSrcFrames) * ratio)
        var outData = Data()
        outData.reserveCapacity(max(1, estimatedDstFrames) * targetChannels * MemoryLayout<Int16>.size)

        let readChunkFrames: AVAudioFrameCount = 32768
        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: readChunkFrames) else { return nil }
        let dstChunkCapacity = AVAudioFrameCount(Double(readChunkFrames) * ratio) + 2048
        guard let dstBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: dstChunkCapacity) else { return nil }

        var totalReadFrames: AVAudioFramePosition = 0

        while totalReadFrames < maxSrcFrames {
            let framesToRead = min(readChunkFrames, AVAudioFrameCount(maxSrcFrames - totalReadFrames))
            srcBuffer.frameLength = 0
            do {
                try audioFile.read(into: srcBuffer, frameCount: framesToRead)
            } catch {
                break
            }
            if srcBuffer.frameLength == 0 { break }
            totalReadFrames += AVAudioFramePosition(srcBuffer.frameLength)

            var hasSuppliedInput = false
            var conversionError: NSError?
            dstBuffer.frameLength = 0

            let status = converter.convert(to: dstBuffer, error: &conversionError) { _, outStatus in
                if !hasSuppliedInput {
                    hasSuppliedInput = true
                    outStatus.pointee = .haveData
                    return srcBuffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            if conversionError != nil || status == .error {
                break
            }

            let framesConverted = Int(dstBuffer.frameLength)
            if framesConverted > 0, let floatChannels = dstBuffer.floatChannelData {
                let channels = Int(dstFormat.channelCount)
                let sampleCount = framesConverted * channels
                var chunkInt16 = [Int16](repeating: 0, count: sampleCount)
                var idx = 0
                for f in 0..<framesConverted {
                    for ch in 0..<channels {
                        let sample = floatChannels[ch][f]
                        chunkInt16[idx] = Int16(clamping: Int((sample * 32767.0).rounded())).littleEndian
                        idx += 1
                    }
                }
                chunkInt16.withUnsafeBytes { rawBytes in
                    outData.append(contentsOf: rawBytes)
                }
            }

            if status == .endOfStream {
                break
            }
        }

        return outData.isEmpty ? nil : outData
    }

    public func loadPCMData(
        for asset: SampleAsset,
        maxDurationSeconds: Double? = nil,
        fallbackDuration: Double = 1.5
    ) -> Data {
        let cacheKey = "\(asset.filename)_\(maxDurationSeconds.map { String($0) } ?? "full")"
        cacheLock.lock()
        if let cached = sampleCache[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        if let url = Self.locateResourceURL(name: asset.filename, ext: asset.fileExtension),
           let pcm = Self.decodeAudioFileToInt16PCM(
                url: url,
                targetSampleRate: asset.targetSampleRate,
                targetChannels: asset.targetChannels,
                maxDurationSeconds: maxDurationSeconds
           ), !pcm.isEmpty {
            cacheLock.lock()
            sampleCache[cacheKey] = pcm
            cacheLock.unlock()
            return pcm
        }

        let fallback = Self.generateSineWavePCM(
            sampleRate: asset.targetSampleRate,
            channelCount: asset.targetChannels,
            frequencyHz: asset.fallbackFrequency,
            durationSeconds: fallbackDuration
        )
        return fallback
    }

    public func clearCache() {
        cacheLock.lock()
        sampleCache.removeAll()
        cacheLock.unlock()
    }

    public func playMediaTestTone() {
        PCMAudioPlayer.shared.reset()
        let vol = Int((ProjectionSettings.mediaVolume * 100).rounded())
        let enabled = ProjectionSettings.isMediaChannelEnabled ? "enabled" : "disabled"
        AudioDiagnostics.shared.record("AudioStreamTester: Playing Media sample (48kHz stereo, vol=\(vol)%, \(enabled))")
        let data = loadPCMData(for: .media, maxDurationSeconds: 4.0)
        PCMAudioPlayer.shared.playPCM(data, on: Channel.ID_AUD)
    }

    public func playGuidanceTestTone() {
        PCMAudioPlayer.shared.reset()
        let vol = Int((ProjectionSettings.navigationVolume * 100).rounded())
        let enabled = ProjectionSettings.isNavigationChannelEnabled ? "enabled" : "disabled"
        AudioDiagnostics.shared.record("AudioStreamTester: Playing Route navigation sample (16kHz mono, vol=\(vol)%, \(enabled))")
        let data = loadPCMData(for: .navigation, maxDurationSeconds: 3.5)
        PCMAudioPlayer.shared.playPCM(data, on: Channel.ID_AU1)
    }

    public func playSystemTestTone() {
        PCMAudioPlayer.shared.reset()
        let vol = Int((ProjectionSettings.phoneSystemVolume * 100).rounded())
        let enabled = ProjectionSettings.isSystemChannelEnabled ? "enabled" : "disabled"
        AudioDiagnostics.shared.record("AudioStreamTester: Playing Phone ringing sample (16kHz mono, vol=\(vol)%, \(enabled))")
        let data = loadPCMData(for: .system, maxDurationSeconds: 3.0)
        PCMAudioPlayer.shared.playPCM(data, on: Channel.ID_AU2)
    }

    public func playDuckingTestSequence() {
        PCMAudioPlayer.shared.reset()
        let duckPct = Int((ProjectionSettings.navigationDuckingAmount * 100).rounded())
        let medVol = Int((ProjectionSettings.mediaVolume * 100).rounded())
        let navVol = Int((ProjectionSettings.navigationVolume * 100).rounded())
        AudioDiagnostics.shared.record("AudioStreamTester: Starting ducking test sequence (Media=\(medVol)%, Nav=\(navVol)%, Ducking=-\(duckPct)%)")
        let mediaData = loadPCMData(for: .media, maxDurationSeconds: 6.0)
        PCMAudioPlayer.shared.playPCM(mediaData, on: Channel.ID_AUD)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self = self else { return }
            AudioDiagnostics.shared.record("AudioStreamTester: Overlaying Route navigation sample (triggering ducking -\(duckPct)%)")
            let guidanceData = self.loadPCMData(for: .navigation, maxDurationSeconds: 4.0)
            PCMAudioPlayer.shared.playPCM(guidanceData, on: Channel.ID_AU1)
        }
    }
}
