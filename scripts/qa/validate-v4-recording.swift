import AVFoundation
import CoreMedia
import Foundation

// Validate the actual Simulator recording, independently of the UI test result.
// No app data is loaded here; the input is this task's video artifact only.
guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: swift validate-v4-recording.swift <video> <receipt.json>\n".utf8))
    exit(2)
}
do {
    let video = URL(fileURLWithPath: CommandLine.arguments[1])
    let asset = AVURLAsset(url: video)
    let duration = try await asset.load(.duration).seconds
    let tracks = try await asset.loadTracks(withMediaType: .video)
    guard duration.isFinite, duration > 0, !tracks.isEmpty else {
        throw NSError(domain: "V4RecordingValidation", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Recording needs a readable video track and positive duration"])
    }
    let formats = try await tracks[0].load(.formatDescriptions)
    guard formats.contains(where: { CMFormatDescriptionGetMediaSubType($0) == kCMVideoCodecType_H264 }) else {
        throw NSError(domain: "V4RecordingValidation", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Expected an H.264 Simulator recording"])
    }
    let first = try await AVAssetImageGenerator(asset: asset).image(at: .zero)
    let receipt: [String: Any] = [
        "codec": "h264",
        "duration_seconds": duration,
        "video_track_count": tracks.count,
        "first_frame_decoded": true,
        "width": first.image.width,
        "height": first.image.height,
        "validation": "AVFoundation loaded the video, verified H.264, and decoded the first frame",
    ]
    let data = try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
    print("Native recording validated: \(duration) seconds, \(tracks.count) video track(s)")
} catch {
    FileHandle.standardError.write(Data("Native recording validation failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
