import Foundation

public final class MicChunkAccumulator {
    public let chunkBytes: Int

    private var chunk: Data
    private var pending = 0
    private var chunkStartedUs: Int64 = 0
    private var chunkPeak = 0

    public var residueBytes: Int {
        return pending
    }

    public var pendingSampleCount: Int {
        return pending / 2
    }

    public init(chunkBytes: Int = 4096) {
        guard chunkBytes > 0 && chunkBytes % 2 == 0 else {
            fatalError("chunk must be a whole number of frames, was \(chunkBytes) bytes")
        }
        self.chunkBytes = chunkBytes
        self.chunk = Data(count: chunkBytes)
    }

    public convenience init(targetChunkSamples: Int) {
        self.init(chunkBytes: targetChunkSamples * 2)
    }

    public func append(samples: [Int16]) -> [[Int16]] {
        var result: [[Int16]] = []
        let byteData = samples.withUnsafeBufferPointer { Data(buffer: $0) }
        offer(src: byteData, srcLen: byteData.count, capturedAtUs: 0, peak: 0) { chunkData, chunkLen, _, _ in
            let chunkSamples = chunkData.prefix(chunkLen).withUnsafeBytes { raw in
                Array(raw.bindMemory(to: Int16.self))
            }
            result.append(chunkSamples)
        }
        return result
    }

    public func offer(
        src: Data,
        srcLen: Int,
        capturedAtUs: Int64,
        peak: Int,
        emit: (Data, Int, Int64, Int) -> Void
    ) {
        _ = offerWhile(src: src, srcLen: srcLen, capturedAtUs: capturedAtUs, peak: peak) { bytes, length, timestamp, level in
            emit(bytes, length, timestamp, level)
            return true
        }
    }

    public func offerWhile(
        src: Data,
        srcLen: Int,
        capturedAtUs: Int64,
        peak: Int,
        emit: (Data, Int, Int64, Int) -> Bool
    ) -> Int {
        var i = 0

        return src.withUnsafeBytes { raw -> Int in
            guard let srcPtr = raw.baseAddress else { return 0 }

            while i < srcLen {
                if pending == 0 {
                    chunkStartedUs = capturedAtUs + bytesToMicros(i)
                    chunkPeak = 0
                }

                let take = min(chunkBytes - pending, srcLen - i)
                chunk.withUnsafeMutableBytes { chunkRaw in
                    if let chunkPtr = chunkRaw.baseAddress {
                        memcpy(chunkPtr.advanced(by: pending), srcPtr.advanced(by: i), take)
                    }
                }

                pending += take
                i += take
                if peak > chunkPeak {
                    chunkPeak = peak
                }

                if pending == chunkBytes {
                    pending = 0
                    if !emit(chunk, chunkBytes, chunkStartedUs, chunkPeak) {
                        _ = reset()
                        return chunkBytes + srcLen - i
                    }
                }
            }
            return 0
        }
    }

    @discardableResult
    public func reset() -> Int {
        let discarded = pending
        pending = 0
        chunkStartedUs = 0
        chunkPeak = 0
        return discarded
    }

    private func bytesToMicros(_ bytes: Int) -> Int64 {
        return Int64(bytes) * 1_000_000 / 32000
    }
}
