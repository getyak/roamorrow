import SwiftUI

/// Real local identity, with a single clear route to profile editing.
struct MeProfileHeader: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dynamicTypeSize) private var typeSize

    private var name: String {
        let handle = preferences.displayHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        return handle.isEmpty ? NSLocalizedString("me.profile.name", comment: "Default name") : handle
    }

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 20))
        layout {
            Text(preferences.companionAvatarEmoji)
                .font(.system(size: 42))
                .frame(width: 80, height: 80)
                .background(CompanionHomeStyle.outgoing, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.title2.weight(.semibold)).tracking(-0.4)
                    .foregroundStyle(CompanionHomeStyle.ink)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(NSLocalizedString("me.profile.edit", comment: "Edit profile"))
                    Image(systemName: "arrow.up.right").font(.caption.weight(.medium))
                }
                .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A quiet record of actual data; no progress or animated score is implied.
struct MeTravelCounts: View {
    let saved: Int
    let explored: Int
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 32))
        layout {
            metric(saved, key: "me.stats.saved")
            metric(explored, key: "me.stats.explored")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityIdentifier("me.travel.counts")
    }

    private func metric(_ count: Int, key: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(count, format: .number)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .foregroundStyle(CompanionHomeStyle.ink)
            Text(NSLocalizedString(key, comment: "Travel count"))
                .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
