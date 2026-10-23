import SwiftUI

/// A single introduction to the new creative loop; no travel questionnaire or paywall.
struct StudioWelcomeView: View {
    let begin: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer()
            Image(systemName: "leaf").font(.system(size: 44, weight: .ultraLight))
            Text("studio.welcome.title").font(.system(size: 36, design: .serif)).lineSpacing(8)
            Text("studio.welcome.body").font(.system(size: 16)).lineSpacing(9)
                .foregroundStyle(StudioStyle.ink.opacity(0.7))
            Spacer()
            Text("studio.local").font(.footnote).foregroundStyle(.secondary)
            Button(action: begin) {
                Text("studio.welcome.begin").font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(20).background(StudioStyle.ink, in: Capsule())
            }
        }.padding(32).background(StudioStyle.paper).foregroundStyle(StudioStyle.ink)
            .preferredColorScheme(.light)
    }
}
