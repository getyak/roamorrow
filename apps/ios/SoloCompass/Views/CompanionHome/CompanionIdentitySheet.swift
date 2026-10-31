import SwiftUI

@MainActor
struct CompanionIdentitySheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var style: CompanionPortraitStyle = .moss
    @State private var loaded = false

    private var validName: Bool {
        !CompanionIdentity.normalizedName(name).isEmpty && name.count <= CompanionIdentity.maximumNameLength
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        CompanionPortrait(style: style, size: 96)
                        Text(CompanionIdentity(name: name, portrait: style).displayName)
                            .font(.title2.weight(.medium)).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                }
                Section {
                    TextField(companionText("companion.identity.name", "名称"), text: $name)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { if validName { save() } }
                        .accessibilityIdentifier("companion.identity.name")
                } header: {
                    Text(companionText("companion.identity.name", "名称"))
                } footer: {
                    Text(companionText("companion.identity.nameHint", "四个字就很好，最多 16 个字。"))
                }
                Section(companionText("companion.identity.appearance", "形象风格")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                        ForEach(CompanionPortraitStyle.allCases) { candidate in
                            Button { style = candidate; Haptics.selection() } label: {
                                VStack(spacing: 10) {
                                    CompanionPortrait(style: candidate, size: 64)
                                    HStack(spacing: 6) {
                                        Text(candidate.title).font(.subheadline)
                                        if candidate == style {
                                            Image(systemName: "checkmark.circle.fill").font(.caption)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 112).padding(8)
                                .background(CompanionHomeStyle.outgoing.opacity(candidate == style ? 0.8 : 0),
                                    in: RoundedRectangle(cornerRadius: 18))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).foregroundStyle(CompanionHomeStyle.ink)
                            .accessibilityLabel(candidate.title)
                            .accessibilityAddTraits(candidate == style ? .isSelected : [])
                            .accessibilityIdentifier("companion.identity.style.\(candidate.rawValue)")
                        }
                    }.padding(.vertical, 8)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(companionText("companion.identity.edit", "我的旅伴"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(companionText("companion.identity.save", "保存"), action: save)
                        .disabled(!validName).accessibilityIdentifier("companion.identity.save")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                name = preferences.agentIdentity.displayName
                style = preferences.agentIdentity.portrait
            }
        }
    }

    private func save() {
        guard validName else { return }
        preferences.agentIdentity = CompanionIdentity(name: name, portrait: style)
        dismiss()
    }
}
