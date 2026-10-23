import SwiftUI
import QuickLook
import ImageIO
import UniformTypeIdentifiers

@MainActor
struct CompanionMediaTile: View {
    let attachment: CompanionMediaAttachment
    var compact = false
    let onOpen: () -> Void
    @Environment(CompanionAudioSession.self) private var audio
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if attachment.kind == .image, let data = attachment.data {
                Button(action: onOpen) {
                    CompanionPhotoThumbnail(data: data)
                        .frame(maxHeight: compact ? 100 : 270)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("companion.media.\(attachment.id)")
                    .accessibilityLabel(companionText("companion.media.openPhoto", "查看照片") + "，" + attachment.name)
            } else if attachment.kind == .audio {
                audioTile
            } else {
                Button(action: onOpen) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: attachment.kind == .place ? "mappin.and.ellipse" : "doc.text")
                            .font(compact ? .body : .title3).frame(width: compact ? 20 : 32).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(attachment.place?.name ?? attachment.name).font((compact ? Font.subheadline : .body).weight(.medium))
                                .lineLimit(compact ? 2 : nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(attachment.kind == .place
                                ? companionText("companion.media.selectedPlace", "地图地点 · 查看详情")
                                : ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file))
                                .font(.footnote).foregroundStyle(CompanionHomeStyle.secondaryInk).lineLimit(compact ? 1 : nil)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote).accessibilityHidden(true)
                    }.padding(12).frame(minHeight: 60).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("companion.media.\(attachment.id)")
                    .background(CompanionHomeStyle.paper.opacity(0.75), in: RoundedRectangle(cornerRadius: 15))
            }
        }
    }

    private var audioTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { audio.togglePlayback(attachment) } label: {
                HStack(spacing: 10) {
                    Image(systemName: audio.playingID == attachment.id ? "pause.fill" : "play.fill")
                        .frame(width: 44, height: 44)
                    if let samples = attachment.samples, !samples.isEmpty, !typeSize.isAccessibilitySize {
                        HStack(spacing: 3) {
                            let reduced = Self.waveform(samples, count: compact ? 10 : 28)
                            ForEach(Array(reduced.enumerated()), id: \.offset) { _, value in
                                Capsule().frame(width: 3, height: max(3, CGFloat(value) * 27))
                            }
                        }.frame(maxWidth: .infinity).accessibilityHidden(true)
                    } else {
                        Text(companionText("companion.media.voice", "语音消息")).font(.body)
                        Spacer(minLength: 0)
                    }
                    Text(Self.duration(attachment.duration ?? 0)).font(.subheadline.monospacedDigit())
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(audio.isRecording)
                .accessibilityLabel((audio.playingID == attachment.id
                    ? companionText("companion.media.pause", "暂停语音") : companionText("companion.media.play", "播放语音"))
                    + "，" + Self.duration(attachment.duration ?? 0))
                .accessibilityIdentifier("companion.audio.play.\(attachment.id)")
            if audio.playbackAttachmentID == attachment.id {
                ProgressView(value: audio.playbackProgress).tint(CompanionHomeStyle.accent)
                    .accessibilityLabel(companionText("companion.media.playbackProgress", "播放进度"))
            }
            if !compact {
                Button(action: onOpen) {
                    Text(companionText("companion.media.audioDetails", "查看原件与文字")).font(.footnote)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("companion.audio.details.\(attachment.id)")
            }
        }.padding(.horizontal, 10)
    }
    static func duration(_ value: Double) -> String {
        let seconds = Int(max(0, value.isFinite ? value : 0).rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    private static func waveform(_ samples: [Float], count maximum: Int) -> [Float] {
        let count = min(maximum, samples.count)
        return (0..<count).map { samples[$0 * samples.count / count] }
    }
}

@MainActor
struct CompanionMediaPreview: View {
    let attachment: CompanionMediaAttachment
    @Environment(\.dismiss) private var dismiss
    @State private var fileURL: URL?
    @State private var failure = false
    var body: some View {
        NavigationStack {
            Group {
                if attachment.kind == .audio {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            CompanionMediaTile(attachment: attachment, compact: true, onOpen: {})
                            if let text = attachment.extractedText, !text.isEmpty {
                                Text(companionText("companion.media.transcript", "语音转写 · 请核对")).font(.headline)
                                Text(text).font(.body).textSelection(.enabled)
                            } else {
                                Text(companionText("companion.media.audioNotTranscribed", "原始录音已保留。这条消息未附转写文字。"))
                                    .foregroundStyle(CompanionHomeStyle.secondaryInk)
                            }
                        }.padding(20)
                    }
                } else if let fileURL {
                    CompanionQuickLook(url: fileURL)
                } else if failure {
                    ContentUnavailableView(companionText("companion.media.previewFailed", "暂时无法预览"), systemImage: "doc.questionmark")
                } else { ProgressView() }
            }
            .navigationTitle(attachment.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(companionText("companion.done", "完成")) { dismiss() }
                }
                if let fileURL {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: fileURL) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel(companionText("companion.media.shareOriginal", "分享原件"))
                    }
                }
            }
        }
        .task {
            do {
                guard let data = attachment.data else { throw CocoaError(.fileReadCorruptFile) }
                let ext = UTType(mimeType: attachment.mimeType)?.preferredFilenameExtension ?? "bin"
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("companion-preview-\(UUID())")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent("media.\(ext)")
                try data.write(to: url, options: .completeFileProtectionUntilFirstUserAuthentication)
                fileURL = url
            } catch { failure = true }
        }
        .onDisappear {
            if let fileURL { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        }
    }
}

private struct CompanionQuickLook: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

private struct CompanionPhotoThumbnail: View {
    let data: Data
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { ProgressView().frame(width: 160, height: 100) }
        }.task {
            image = await Task.detached(priority: .userInitiated) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1_200,
                        kCGImageSourceCreateThumbnailWithTransform: true
                      ] as CFDictionary) else { return nil as UIImage? }
                return UIImage(cgImage: thumbnail)
            }.value
        }
    }
}
