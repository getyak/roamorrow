#!/usr/bin/env swift
import AVFoundation
import CoreMedia
import Foundation

// Re-encode existing native recording pixels; this never draws or generates UI.
// Usage: swift scripts/qa/export-v4-preview.swift input.mp4 output.mp4
// Keeps the complete recording up to 90 seconds, otherwise its last 90 seconds.
// The original recording remains the interaction evidence; this is a download preview.

struct PreviewError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func exportPreview(input: URL, output: URL) async throws {
    guard input.standardizedFileURL != output.standardizedFileURL else {
        throw PreviewError(message: "Input and output must be different files")
    }
    guard !FileManager.default.fileExists(atPath: output.path) else {
        throw PreviewError(message: "Output already exists; choose a new path")
    }
    let asset = AVURLAsset(url: input)
    let duration = try await asset.load(.duration)
    guard duration.seconds.isFinite, duration.seconds > 0,
          let track = try await asset.loadTracks(withMediaType: .video).first else {
        throw PreviewError(message: "Input needs a video track and positive duration")
    }
    let size = try await track.load(.naturalSize)
    let preferredTransform = try await track.load(.preferredTransform)
    let displayBounds = CGRect(origin: .zero, size: size).applying(preferredTransform).standardized
    guard displayBounds.width.isFinite, displayBounds.height.isFinite,
          displayBounds.width > 0, displayBounds.height > 0 else {
        throw PreviewError(message: "Input has invalid video dimensions")
    }
    let scale = min(1, 1280 / max(displayBounds.width, displayBounds.height))
    let width = max(2, Int(floor(displayBounds.width * scale / 2)) * 2)
    let height = max(2, Int(floor(displayBounds.height * scale / 2)) * 2)
    // Uniform scaling avoids stretching; rounding can leave a subpixel border.
    let renderScale = min(CGFloat(width) / displayBounds.width, CGFloat(height) / displayBounds.height)
    let transform = preferredTransform
        .concatenating(CGAffineTransform(translationX: -displayBounds.minX, y: -displayBounds.minY))
        .concatenating(CGAffineTransform(scaleX: renderScale, y: renderScale))
        .concatenating(CGAffineTransform(
            translationX: (CGFloat(width) - displayBounds.width * renderScale) / 2,
            y: (CGFloat(height) - displayBounds.height * renderScale) / 2))
    let previewDuration = CMTimeMinimum(duration, CMTime(value: 90, timescale: 1))
    let range = CMTimeRange(start: CMTimeSubtract(duration, previewDuration), duration: previewDuration)
    // simctl produces variable-rate video; its low average FPS must not set the
    // cadence of animated sections. Render the download preview at 30 FPS.
    let fps = 30.0
    let composition = AVMutableVideoComposition()
    composition.renderSize = CGSize(width: width, height: height)
    composition.frameDuration = CMTime(seconds: 1 / fps, preferredTimescale: 60_000)
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    layer.setTransform(transform, at: .zero)
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = range
    instruction.layerInstructions = [layer]
    composition.instructions = [instruction]

    let reader = try AVAssetReader(asset: asset)
    reader.timeRange = range
    let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
    ])
    videoOutput.videoComposition = composition
    videoOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(videoOutput) else { throw PreviewError(message: "Cannot read input video") }
    reader.add(videoOutput)

    let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 1_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalDurationKey: 2,
            AVVideoExpectedSourceFrameRateKey: fps,
        ],
    ])
    videoInput.expectsMediaDataInRealTime = false
    guard writer.canAdd(videoInput) else { throw PreviewError(message: "Cannot write H.264 video") }
    writer.add(videoInput)

    // Simulator recordings are usually silent. Preserve an audio track if present.
    var audioOutput: AVAssetReaderTrackOutput?
    var audioInput: AVAssetWriterInput?
    if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
        let readerAudio = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
        ])
        readerAudio.alwaysCopiesSampleData = false
        let writerAudio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 96_000,
        ])
        guard reader.canAdd(readerAudio), writer.canAdd(writerAudio) else {
            throw PreviewError(message: "Cannot preserve input audio")
        }
        reader.add(readerAudio)
        writer.add(writerAudio)
        audioOutput = readerAudio
        audioInput = writerAudio
    }

    var completed = false
    defer {
        if !completed {
            reader.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: output)
        }
    }
    guard writer.startWriting() else { throw writer.error ?? PreviewError(message: "Cannot start writer") }
    writer.startSession(atSourceTime: range.start)
    guard reader.startReading() else { throw reader.error ?? PreviewError(message: "Cannot start reader") }
    var videoDone = false
    var audioDone = audioInput == nil
    // Feed both tracks together so neither can block the other's interleaving.
    while !videoDone || !audioDone {
        if writer.status == .failed { throw writer.error ?? PreviewError(message: "Writer failed") }
        if reader.status == .failed { throw reader.error ?? PreviewError(message: "Reader failed") }
        var advanced = false
        if !videoDone, videoInput.isReadyForMoreMediaData {
            if let sample = videoOutput.copyNextSampleBuffer() {
                guard videoInput.append(sample) else {
                    throw writer.error ?? PreviewError(message: "Cannot append video frame")
                }
            } else {
                videoInput.markAsFinished()
                videoDone = true
            }
            advanced = true
        }
        if !audioDone, let audioInput, let audioOutput, audioInput.isReadyForMoreMediaData {
            if let sample = audioOutput.copyNextSampleBuffer() {
                guard audioInput.append(sample) else {
                    throw writer.error ?? PreviewError(message: "Cannot append audio sample")
                }
            } else {
                audioInput.markAsFinished()
                audioDone = true
            }
            advanced = true
        }
        if !advanced { usleep(2_000) }
    }
    guard reader.status == .completed else {
        throw reader.error ?? PreviewError(message: "Input reading did not complete")
    }
    writer.endSession(atSourceTime: range.end)
    await writer.finishWriting()
    guard writer.status == .completed else {
        throw writer.error ?? PreviewError(message: "Output writing did not complete")
    }
    completed = true
    let bytes = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    let metadata: [String: Any] = [
        "output": output.path, "codec": "h264", "width": width, "height": height,
        "duration_seconds": range.duration.seconds, "source_start_seconds": range.start.seconds,
        "bytes": bytes, "audio_preserved": audioInput != nil, "network_optimized": true,
    ]
    let data = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: swift export-v4-preview.swift input.mp4 output.mp4\n".utf8))
    exit(2)
}
do {
    try await exportPreview(input: URL(fileURLWithPath: CommandLine.arguments[1]),
                            output: URL(fileURLWithPath: CommandLine.arguments[2]))
} catch {
    FileHandle.standardError.write(Data("Preview export failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
