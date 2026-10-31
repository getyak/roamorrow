import SwiftUI

@MainActor
struct CompanionMessageRow: View {
    let entry: CompanionHomeEntry
    var replyContext: String? = nil
    let onRetry: () -> Void
    let onSources: () -> Void
    let onPlace: (String) -> Void
    let onMedia: (CompanionMediaAttachment) -> Void
    let onQuote: (CompanionQuotedMessage) -> Void
    let onReaction: () -> Void
    @Environment(ExperienceService.self) private var experiences
    @Environment(\.dynamicTypeSize) private var typeSize
    private var isUser: Bool { entry.role == .user }
    private var parts: [String] {
        let response = isUser ? entry.text : CompanionHomeAgent.userFacingResponse(entry.text)
        guard !isUser, (entry.attachments ?? []).isEmpty, entry.quotedMessage == nil,
              replyContext == nil, entry.placeID == nil else { return response.isEmpty ? [] : [response] }
        return CompanionReplyLayout.parts(response)
    }
    private var quotation: CompanionQuotedMessage {
        .init(entryID: entry.id, role: entry.role,
              text: String((entry.text.isEmpty ? (entry.attachments?.first?.name ?? "") : entry.text).prefix(600)))
    }

    var body: some View {
        let parts = self.parts
        return HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: typeSize.isAccessibilitySize ? 8 : 30) }
            VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parts.dropLast().enumerated()), id: \.offset) { index, part in
                formatted(part).font(.body).lineSpacing(4).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(index == 0 ? bodyIdentifier : "companion.message.part.\(entry.id).\(index)")
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(CompanionHomeStyle.incoming, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 10) {
                if let quote = entry.quotedMessage {
                    quoteBlock(quote.text)
                } else if let replyContext { quoteBlock(replyContext) }
                ForEach(entry.attachments ?? []) { attachment in
                    CompanionMediaTile(attachment: attachment) { onMedia(attachment) }
                    if let text = attachment.extractedText, !text.isEmpty {
                        DisclosureGroup {
                            Text(text).font(.subheadline).textSelection(.enabled).padding(.top, 8)
                                .fixedSize(horizontal: false, vertical: true)
                        } label: {
                            Text(companionText("companion.media.extracted", "查看识别文字 · 请核对"))
                                .frame(minHeight: 44).contentShape(Rectangle())
                        }.font(.footnote).tint(CompanionHomeStyle.ink)
                    }
                }
                if let last = parts.last {
                    formatted(last).font(.body).lineSpacing(4).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(parts.count == 1 ? bodyIdentifier : "companion.message.part.\(entry.id).\(parts.count - 1)")
                }
                ForEach(entry.mapPlaceIDs.prefix(3), id: \.self) { id in
                    if let experience = experiences.getExperience(id: id) {
                    Button { onPlace(id) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse").accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(experience.shortName).font(.body.weight(.medium))
                                Text(companionText("companion.map.showResult", "在地图上看"))
                                    .font(.footnote).foregroundStyle(CompanionHomeStyle.secondaryInk)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.footnote).accessibilityHidden(true)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("companion.message.map.\(entry.id).\(id)")
                    }
                }
                if !entry.mapPlaceIDs.isEmpty || entry.sourceTitles.contains(where: { $0.hasPrefix("本轮网页检索") || $0.hasPrefix("工具返回资料") }) {
                    Button(action: onSources) {
                        Label(companionText("companion.sources.open", "查看依据"), systemImage: "text.quote")
                            .font(.footnote).frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(CompanionHomeStyle.secondaryInk)
                        .accessibilityIdentifier("companion.sources.\(entry.id)")
                }
                if isUser && (entry.status == .failed || entry.status == .queued) {
                    Button(action: onRetry) {
                        Label(companionText("companion.im.retry", "尚未完成 · 重试"), systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("companion.retry.\(entry.id)")
                }
                if entry.reaction == "heart" {
                    Button(action: onReaction) {
                        Image(systemName: "heart.fill").font(.subheadline).frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(.plain).accessibilityLabel(companionText("companion.im.removeHeart", "移除我标记的喜欢"))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(isUser ? CompanionHomeStyle.outgoing : CompanionHomeStyle.incoming,
                        in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            }
            .contextMenu {
                if !entry.sourceTitles.isEmpty {
                    Button(companionText("companion.sources.open", "查看依据"), systemImage: "text.quote", action: onSources)
                }
                Button(companionText("companion.im.heart", "标记喜欢"), systemImage: "heart") { onReaction() }
                Button(companionText("companion.im.reply", "引用回复"), systemImage: "arrowshape.turn.up.left") { onQuote(quotation) }
                if !entry.text.isEmpty {
                    Button(companionText("companion.im.copy", "复制文字"), systemImage: "doc.on.doc") { UIPasteboard.general.string = entry.text }
                }
            }
            .accessibilityActions {
                if !entry.sourceTitles.isEmpty { Button(companionText("companion.sources.open", "查看依据"), action: onSources) }
            }
            .accessibilityAction(named: Text(companionText("companion.im.heart", "标记喜欢"))) { onReaction() }
            .accessibilityAction(named: Text(companionText("companion.im.reply", "引用回复"))) { onQuote(quotation) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("companion.message.\(entry.id)")
        }
        .foregroundStyle(CompanionHomeStyle.ink)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
    private func quoteBlock(_ text: String) -> some View {
        Text(text).font(.subheadline).lineLimit(3).foregroundStyle(CompanionHomeStyle.secondaryInk)
            .padding(.leading, 10).padding(.vertical, 4)
            .overlay(alignment: .leading) { CompanionHomeStyle.accent.opacity(0.5).frame(width: 2) }
            .accessibilityLabel(companionText("companion.im.quoted", "引用") + "：" + text)
    }
    private var bodyIdentifier: String {
        entry.replyToID.map { "companion.reply-to.\($0)" } ?? "companion.message.body.\(entry.id)"
    }
    private func formatted(_ response: String) -> some View {
        CompanionFormattedMessageText(response: response, isUser: isUser).equatable()
    }
}

/// Value-only inputs let SwiftUI retain parsed text while scroll state changes.
private struct CompanionFormattedMessageText: View, Equatable {
    let response: String
    let isUser: Bool
    var body: some View { rendered }

    private var rendered: Text {
        guard !isUser else { return Text(response) }
        guard var formatted = try? AttributedString(markdown: response,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else { return Text(response) }
        let ranges = formatted.runs.compactMap { $0.link == nil ? nil : $0.range }
        for range in ranges { formatted[range].link = nil }
        return Text(formatted)
    }
}
