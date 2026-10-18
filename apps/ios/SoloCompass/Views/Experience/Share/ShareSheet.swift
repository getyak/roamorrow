import SwiftUI
import UIKit

/// Unified share sheet: lets the user pick between four visual card styles
/// (Xiaohongshu / Twitter / Instagram / Minimal) or fall back to the original
/// Markdown PKM export. Replaces the standalone `MarkdownShareSheet` as the
/// detail view's share entry point.
///
/// Saving to Photos is delegated to the system share sheet's built-in
/// "Save Image" action, so we don't need NSPhotoLibraryAddUsageDescription.
struct ShareSheet: View {
    let experience: Experience
    let markdown: String
    let notionURL: URL?

    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: ShareMode = .xiaohongshuPortrait
    @State private var activityItems: [Any]? = nil
    @State private var statusMessage: String? = nil
    @State private var statusIsError: Bool = false
    /// Pre-rendered preview bitmap for the current card style. Rendering once into a
    /// static image avoids per-frame re-compositing of `.ultraThinMaterial`, shadows and
    /// gradients under `scaleEffect`/sheet animation — the source of the preview flicker.
    @State private var previewImage: UIImage? = nil
    /// True when the card render failed: the preview shows an explanation and a
    /// retry instead of an endless spinner (I11).
    @State private var previewFailed = false

    enum ShareMode: Hashable, Identifiable, CaseIterable {
        case xiaohongshuPortrait
        case twitterLandscape
        case instagramSquare
        case minimalText
        case markdown

        var id: String { String(describing: self) }

        var label: String {
            switch self {
            case .xiaohongshuPortrait: return NSLocalizedString("share.mode.xiaohongshu", comment: "")
            case .twitterLandscape:    return NSLocalizedString("share.mode.twitter", comment: "")
            case .instagramSquare:     return NSLocalizedString("share.mode.square", comment: "")
            case .minimalText:         return NSLocalizedString("share.mode.minimal", comment: "")
            case .markdown:            return NSLocalizedString("share.mode.markdown", comment: "")
            }
        }

        var cardStyle: ShareCardStyle? {
            switch self {
            case .xiaohongshuPortrait: return .xiaohongshuPortrait
            case .twitterLandscape:    return .twitterLandscape
            case .instagramSquare:     return .instagramSquare
            case .minimalText:         return .minimalText
            case .markdown:            return nil
            }
        }
    }

    private var payload: ShareCardPayload {
        ShareCardPayload(experience: experience)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                modePicker
                previewArea
                if let status = statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(statusIsError ? CT.savedRed : CT.verifiedGreen)
                        .transition(.opacity)
                }
                actionButtons
            }
            .padding(20)
            .navigationTitle(NSLocalizedString("share.title", comment: "Share"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "Close")) { dismiss() }
                }
            }
        }
        .sheet(item: Binding(
            get: { activityItems.map { ActivityPayload(items: $0) } },
            set: { if $0 == nil { activityItems = nil } }
        )) { payload in
            ActivityViewControllerWrapper(items: payload.items)
        }
        .presentationDetents([.large])
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ShareMode.allCases) { mode in
                    let isSelected = selectedMode == mode
                    Button {
                        if mode != selectedMode { previewImage = nil }
                        selectedMode = mode
                        statusMessage = nil
                    } label: {
                        Text(mode.label)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            // Compact chip visuals, 44pt tap target.
                            .frame(minHeight: HitTargetMetrics.minimum)
                            .background(
                                Capsule().fill(isSelected ? CT.accent : Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(mode.label))
                    .accessibilityValue(Text(isSelected
                        ? NSLocalizedString("common.selected", comment: "Selected")
                        : ""))
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewArea: some View {
        if let style = selectedMode.cardStyle {
            cardPreview(for: style)
        } else {
            markdownPreview
        }
    }

    private func cardPreview(for style: ShareCardStyle) -> some View {
        let aspect = style.renderSize.width / style.renderSize.height
        return ZStack {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(aspect, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
            } else if previewFailed {
                // Honest failure surface with a real retry path (I11).
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .aspectRatio(aspect, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title3)
                                .foregroundStyle(CT.bannerError)
                            Text(NSLocalizedString("share.preview.failed", comment: "Preview could not be rendered"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button(NSLocalizedString("share.preview.retry", comment: "Retry preview")) {
                                previewFailed = false
                                previewImage = nil
                                Task { await renderPreview(for: style) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                    }
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .aspectRatio(aspect, contentMode: .fit)
                    .overlay(ProgressView())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: style) { await renderPreview(for: style) }
    }

    /// Render the current card to a static bitmap off the animation path, then publish it
    /// for display. Re-runs whenever the selected style changes (via `.task(id:)`).
    /// The requested style is frozen as the render/cache key and a result is only
    /// committed while that style is still the selected one — a stale render from
    /// a fast mode switch can never overwrite the new style's preview (I11/I21).
    @MainActor
    private func renderPreview(for style: ShareCardStyle) async {
        do {
            let rendered = try ShareCardRenderer.renderImage(payload: payload, style: style)
            guard selectedMode.cardStyle == style, !Task.isCancelled else { return }
            previewImage = rendered
            previewFailed = false
        } catch {
            guard selectedMode.cardStyle == style, !Task.isCancelled else { return }
            previewImage = nil
            previewFailed = true
        }
    }

    private var markdownPreview: some View {
        ScrollView {
            Text(markdown)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        if let style = selectedMode.cardStyle {
            cardActions(style: style)
        } else {
            markdownActions
        }
    }

    private func cardActions(style: ShareCardStyle) -> some View {
        VStack(spacing: 10) {
            Button {
                shareCard(style: style)
            } label: {
                Label(
                    NSLocalizedString("share.systemShare", comment: "Share via system sheet"),
                    systemImage: "square.and.arrow.up"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                copyImage(style: style)
            } label: {
                Label(
                    NSLocalizedString("share.copyImage", comment: "Copy image"),
                    systemImage: "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text(NSLocalizedString("share.saveHint", comment: "Hint to use Save Image in the system share sheet"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var markdownActions: some View {
        VStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = markdown
                flashStatus(NSLocalizedString("share.copied", comment: "Copied"), error: false)
            } label: {
                Label(
                    NSLocalizedString("export.copy", comment: "Copy Markdown"),
                    systemImage: "doc.on.clipboard"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let url = notionURL {
                Link(destination: url) {
                    Label(
                        NSLocalizedString("export.notion", comment: "Open in Notion"),
                        systemImage: "arrow.up.right.square"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                activityItems = [markdown]
            } label: {
                Label(
                    NSLocalizedString("export.share", comment: "Share…"),
                    systemImage: "square.and.arrow.up"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Card actions impl

    private func shareCard(style: ShareCardStyle) {
        do {
            let url = try ShareCardRenderer.renderTempPNG(payload: payload, style: style)
            activityItems = [url]
        } catch {
            flashStatus(NSLocalizedString("share.renderFailed", comment: ""), error: true)
        }
    }

    private func copyImage(style: ShareCardStyle) {
        do {
            let image = try ShareCardRenderer.renderImage(payload: payload, style: style)
            UIPasteboard.general.image = image
            flashStatus(NSLocalizedString("share.imageCopied", comment: ""), error: false)
        } catch {
            flashStatus(NSLocalizedString("share.renderFailed", comment: ""), error: true)
        }
    }

    private func flashStatus(_ message: String, error: Bool) {
        Haptics.notify(error ? .error : .success)
        withAnimation { statusMessage = message; statusIsError = error }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { statusMessage = nil }
        }
    }
}

// MARK: - ActivityViewController bridging

private struct ActivityPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
