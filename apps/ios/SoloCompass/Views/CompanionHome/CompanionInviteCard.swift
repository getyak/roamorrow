import SwiftUI

struct CompanionInviteCard: View {
    let invite: CompanionHomeInvite
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(companionText("companion.invite.draft", "邀约草稿 · 尚未发送"), systemImage: "person.2")
                .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
            if invite.createdAt == nil {
                Text(companionText("companion.invite.legacy", "较早保存 · 创建时间未记录"))
                    .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
            }
            Text(invite.placeName).font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.date, format: .dateTime.month().day().hour().minute()).font(.subheadline)
                Text(String(format: companionText("companion.invite.duration", "%d 分钟 · %@"), invite.durationMinutes, TimeZone.current.localizedName(for: .generic, locale: Locale.current) ?? TimeZone.current.identifier))
                    .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
            }
            if !invite.people.isEmpty {
                Text(invite.people.map(\.name).joined(separator: "、")).font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
            }
            if !invite.note.isEmpty { Text(invite.note).font(.subheadline).textSelection(.enabled) }
            ShareLink(item: "\(invite.placeName)\n\(invite.date.formatted(date: .abbreviated, time: .shortened)) (\(TimeZone.current.identifier))\n\(String(format: companionText("companion.invite.durationOnly", "%d 分钟"), invite.durationMinutes))\n\(invite.note)") {
                Label(companionText("companion.invite.share", "由我分享邀约"), systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44).contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(CompanionHomeStyle.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("companion.invite.\(invite.id)")
    }
}
