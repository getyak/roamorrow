import SwiftUI

struct CompanionWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                Image(systemName: "sun.horizon")
                    .font(.largeTitle.weight(.ultraLight))
                    .padding(.top, 40)
                Text(companionText("companion.onboarding.title", "把城市，\n慢慢走近。"))
                    .font(.system(.largeTitle, design: .serif))
                    .lineSpacing(7)
                VStack(alignment: .leading, spacing: 26) {
                    point("bubble.left", title: companionText("companion.onboarding.now", "此刻，从一句话开始"),
                          detail: companionText("companion.onboarding.nowBody", "你的原话、下一步和没办完的事，留在同一段同行里。"))
                    point("map", title: companionText("companion.onboarding.map", "想逛的时候，打开附近"),
                          detail: companionText("companion.onboarding.mapBody", "在地图上看看，再决定去哪儿、和谁一起。"))
                }
                Text(companionText("companion.onboarding.privacy", "需要定位或语音时，再由你开启。分享来的资料，会先放进草稿。"))
                    .font(.footnote).foregroundStyle(.secondary).lineSpacing(5)
            }
            .frame(maxWidth: 520, alignment: .leading).padding(30).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text(companionText("companion.onboarding.start", "开始同行"))
                    .font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(CompanionHomeStyle.paper)
                    .background(CompanionHomeStyle.ink, in: Capsule())
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background(CompanionHomeStyle.paper)
        }
        .foregroundStyle(CompanionHomeStyle.ink)
        .background(CompanionHomeStyle.paper.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func point(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title3).frame(width: 26).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).lineSpacing(4)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}
