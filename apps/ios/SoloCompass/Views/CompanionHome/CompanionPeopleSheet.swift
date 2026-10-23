import SwiftUI

@MainActor
struct CompanionPeopleSheet: View {
  let store: CompanionHomeStore
  var isEmbedded = false
  /// An invitation edits its own recipients without replacing the top-level intention.
  var initialPeople: [CompanionHomePerson]? = nil
  var onSelectionSaved: (([CompanionHomePerson]) -> Void)? = nil
  @Environment(\.dismiss) private var dismiss
  @State private var selection: Set<String> = []
  @State private var localName = ""
  @State private var additions: [CompanionHomePerson] = []
  @State private var friends = FriendService.shared

  private var confirmedPeople: [CompanionHomePerson] {
    guard let userID = SupabaseClient.shared.currentSession?.userId else { return [] }
    return friends.friends.filter { $0.userLowId == userID || $0.userHighId == userID }.map {
      let id = $0.otherUserId(viewer: userID)
      return CompanionHomePerson(
        id: id,
        name: store.people.first(where: { $0.id == id && !$0.name.isEmpty && $0.name != id })?.name
          ?? initialPeople?.first(where: { $0.id == id && !$0.name.isEmpty && $0.name != id })?.name
          ?? (companionMapText("companion.people.unnamed", "好友") + " · " + String(id.suffix(4))))
    }
  }

  private var candidates: [CompanionHomePerson] {
    var seen: Set<String> = []
    return (confirmedPeople + (initialPeople ?? []) + store.people + additions).filter { seen.insert($0.id).inserted }
  }

  var body: some View {
    Group {
      if isEmbedded { content } else { NavigationStack { content } }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .onAppear { selection = initialPeople.map { Set($0.map(\.id)) } ?? store.selectedPeopleIDs }
  }

  private var content: some View {
    Form {
      Section {
        Button {
          selection.removeAll()
        } label: {
          HStack {
            Label(companionMapText("companion.people.solo", "这次自己走"), systemImage: "figure.walk")
            Spacer()
            if selection.isEmpty { Image(systemName: "checkmark") }
          }.frame(minHeight: 44)
        }.foregroundStyle(.primary)
        ForEach(candidates) { person in
          Button {
            toggle(person.id)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "person.crop.circle").font(.title2)
              VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                Text(provenance(person)).companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
              }
              Spacer()
              if selection.contains(person.id) { Image(systemName: "checkmark.circle.fill") }
            }.frame(minHeight: 44)
          }
          .foregroundStyle(.primary)
          .accessibilityAddTraits(selection.contains(person.id) ? .isSelected : [])
        }
        Text(companionMapText("companion.people.intent", "这里只记录这次想与谁同行。不会通知对方，也不代表对方已答应；不会共享位置。"))
          .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      Section {
        Text(companionMapText("companion.people.local", "先记下一个名字"))
          .companionMetadata(weight: .medium)
          .foregroundStyle(CompanionHomeStyle.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
        TextField(companionMapText("companion.people.name", "名字或称呼"), text: $localName)
          .textInputAutocapitalization(.words).submitLabel(.done)
          .onSubmit(addLocalPerson).accessibilityIdentifier("companion.people.name")
        Button(action: addLocalPerson) {
          Text(companionMapText("companion.people.add", "添加本机记名"))
            .font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(CompanionPeopleAddButtonStyle())
        .disabled(localName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityIdentifier("companion.people.add")
      }
      if let error = store.errorMessage {
        Section { Text(error).companionMetadata().foregroundStyle(.red) }
      }
      if candidates.isEmpty {
        Section {
          Text(companionMapText("companion.people.empty", "还没有可选人选。登录后的已确认好友会显示在这里，也可以先在本机记下名字。"))
            .foregroundStyle(CompanionHomeStyle.secondaryInk)
        }
      }
    }
    .navigationTitle(companionMapText("companion.people.title", "这次和谁同行"))
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      HStack {
        if !isEmbedded {
          Button { dismiss() } label: {
            Text(companionMapText("companion.common.cancel", "取消"))
              .font(.body).frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityIdentifier("companion.people.cancel")
        }
        Spacer()
        Button {
          var people = store.people
          for person in confirmedPeople + (initialPeople ?? []) + additions
          where !people.contains(where: { $0.id == person.id }) {
            people.append(person)
          }
          store.clearError()
          let selectsGlobalIntention = initialPeople == nil
          if store.updatePeople(people, selectedIDs: selectsGlobalIntention ? selection : nil) {
            onSelectionSaved?(people.filter { selection.contains($0.id) })
            dismiss()
          }
        } label: {
          Text(companionMapText("companion.common.done", "完成"))
            .font(.body.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("companion.people.done")
      }
      .buttonStyle(.plain)
      .padding(.horizontal, CompanionHomeStyle.inset).padding(.vertical, 4)
      .foregroundStyle(CompanionHomeStyle.ink)
      .background(CompanionHomeStyle.paper)
    }

  }

  private func provenance(_ person: CompanionHomePerson) -> String {
    if person.isExample { return companionMapText("companion.people.example", "示意人选 · 未联系") }
    if confirmedPeople.contains(where: { $0.id == person.id }) {
      return companionMapText("companion.people.friend", "已确认好友 · 本次尚未邀约")
    }
    return companionMapText("companion.people.localOnly", "仅本机记名 · 未联系")
  }

  private func toggle(_ id: String) {
    if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
  }

  private func addLocalPerson() {
    let name = String(localName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
    guard !name.isEmpty else { return }
    if let existing = candidates.first(where: { $0.name == name && $0.id.hasPrefix("local-") }) {
      selection.insert(existing.id)
    } else {
      let person = CompanionHomePerson(id: "local-\(UUID().uuidString)", name: name)
      additions.append(person)
      selection.insert(person.id)
    }
    localName = ""
  }
}

private struct CompanionPeopleAddButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(isEnabled ? CompanionHomeStyle.ink : CompanionHomeStyle.secondaryInk)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .contentShape(Rectangle())
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}
