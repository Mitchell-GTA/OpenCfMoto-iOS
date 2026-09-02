// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Hardware H.264 Encoder (VideoToolbox)

import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo

public final class VideoToolboxEncoder {
    public typealias Logger = (String) -> Void
    private let log: Logger

    public let width: Int32
    public let height: Int32
    public let fps: Int32
    public let bitrate: Int32

    private var compressionSession: VTCompressionSession?
    private var frameNumber: Int64 = 0
    private var isConfigured = false

    // Thread-safe FIFO queue of encoded H.264 access units
    private let queueLock = NSLock()
    private var encodedFrames = [Data]()
    private let maxQueuedFrames = 30

    // Annex-B start code
    private static let startCode = Data([0x00, 0x00, 0x00, 0x01])

    public init(width: Int32 = 800, height: Int32 = 384, fps: Int32 = 25, bitrate: Int32 = 2_500_000, logger: @escaping Logger = { print($0) }) {
        self.width = width
        self.height = height
        self.fps = fps
        self.bitrate = bitrate
        self.log = logger
    }

    deinit {
        stop()
    }

    public func start() {
        guard !isConfigured else { return }

        log("[VIDEO] Initializing VideoToolbox H.264 session (\(width)x\(height) @ \(fps)fps, \(bitrate/1000)kbps)...")

        let callback: VTCompressionOutputCallback = { outputCallbackRefCon, _, status, flags, sampleBuffer in
            guard let refCon = outputCallbackRefCon, status == noErr, let sampleBuffer = sampleBuffer else {
                return
            }
            let encoder = Unmanaged<VideoToolboxEncoder>.fromOpaque(refCon).takeUnretainedValue()
            encoder.handleSampleBuffer(sampleBuffer, flags: flags)
        }

        let refCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: callback,
            refcon: refCon,
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            log("[VIDEO] Failed to create VTCompressionSession: status=\(status)")
            return
        }

        self.compressionSession = session

        // Configure session for Ultra-Low Latency Realtime Streaming
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: bitrate))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: fps))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: fps * 2)) // Keyframe every 2 sec

        VTCompressionSessionPrepareToEncodeFrames(session)
        isConfigured = true
        log("[VIDEO] VideoToolbox H.264 compression session ready.")
    }

    public func stop() {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        isConfigured = false
        queueLock.lock()
        encodedFrames.removeAll()
        queueLock.unlock()
    }

    /// Feeds a CVPixelBuffer to be encoded into H.264
    public func encode(pixelBuffer: CVPixelBuffer) {
        guard isConfigured, let session = compressionSession else { return }

        let presentationTime = CMTime(value: frameNumber, timescale: fps)
        let duration = CMTime(value: 1, timescale: fps)

        var flags: VTEncodeInfoFlags = []
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: duration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )

        if status != noErr {
            log("[VIDEO] Encode frame error: \(status)")
        }

        frameNumber += 1
    }

    /// Pulls the next ready H.264 access unit for the bike
    public func pollFrame() -> Data? {
        queueLock.lock()
        defer { queueLock.unlock() }

        guard !encodedFrames.isEmpty else { return nil }
        return encodedFrames.removeFirst()
    }

    // MARK: - Sample Buffer & Annex-B NAL Formatting

    private func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer, flags: VTEncodeInfoFlags) {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        let isKeyframe = !CFDictionaryContainsKey(
            unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false), 0), to: CFDictionary.self),
            Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque()
        )

        var frameData = Data()

        // 1. If keyframe, prepend SPS and PPS parameter sets
        if isKeyframe, let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            var paramSetCount = 0
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil, parameterSetCountOut: &paramSetCount, nalUnitHeaderLengthOut: nil)

            for i in 0..<paramSetCount {
                var paramPointer: UnsafePointer<UInt8>?
                var paramSize: Int = 0
                CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                    formatDesc,
                    parameterSetIndex: i,
                    parameterSetPointerOut: &paramPointer,
                    parameterSetSizeOut: &paramSize,
                    parameterSetCountOut: nil,
                    nalUnitHeaderLengthOut: nil
                )

                if let paramPointer = paramPointer, paramSize > 0 {
                    frameData.append(VideoToolboxEncoder.startCode)
                    frameData.append(paramPointer, count: paramSize)
                }
            }
        }

        // 2. Convert AVCC length-prefixed NAL units into Annex-B start-code format
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)

        if let dataPointer = dataPointer {
            var bufferOffset = 0
            let avccHeaderLength = 4 // Standard 4-byte NAL length prefix in AVCC

            while bufferOffset < totalLength - avccHeaderLength {
                var nalUnitLength: UInt32 = 0
                memcpy(&nalUnitLength, dataPointer + bufferOffset, avccHeaderLength)
                nalUnitLength = CFSwapInt32BigToHost(nalUnitLength)

                frameData.append(VideoToolboxEncoder.startCode)
                frameData.append(UnsafeRawPointer(dataPointer + bufferOffset + avccHeaderLength), count: Int(nalUnitLength))

                bufferOffset += avccHeaderLength + Int(nalUnitLength)
            }
        }

        // 3. Push to FIFO frame queue
        queueLock.lock()
        if encodedFrames.count >= maxQueuedFrames {
            encodedFrames.removeFirst() // Drop oldest frame if network is congested
        }
        encodedFrames.append(frameData)
        queueLock.unlock()
    }
}
