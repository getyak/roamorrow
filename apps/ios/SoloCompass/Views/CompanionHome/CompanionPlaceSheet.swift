import MapKit
import SwiftUI

@MainActor
struct CompanionPlaceSheet: View {
  let experience: Experience
  let store: CompanionHomeStore
  var onInviteSaved: (() -> Void)? = nil
  var distanceOrigin: CLLocationCoordinate2D? = nil
  var distanceUsesGPS = false
  @Environment(UserPreferences.self) private var preferences
  @Environment(\.dismiss) private var dismiss
  @State private var date = Date().addingTimeInterval(3600)
  @State private var duration = 60
  @State private var note = ""
  @State private var inviteID = UUID()
  @State private var saved = false
  @State private var saving = false
  @State private var choosingPeople = false
  @State private var didRestore = false
  @State private var originalDraft: CompanionHomeInvite?
  @State private var localPeople: [CompanionHomePerson] = []
  @State private var showingCloseOptions = false
  @State private var invitationExpanded = false
  @State private var sourcesExpanded = false
  @State private var originalExpanded = false

  private var chinese: Bool {
    LanguageService.shared.effectiveLocale.language.languageCode?.identifier == "zh"
  }
  private var summary: String {
    CompanionPlacePresentation.summary(experience.oneLiner, chinese: chinese)
  }

  private var selectedPeople: [CompanionHomePerson] {
    localPeople
  }

  private var hasEdited: Bool {
    guard let originalDraft else { return false }
    return makeDraft() != originalDraft
  }

  var body: some View {
    placeContent
      .onAppear {
        guard !didRestore else { return }
        restoreDraft()
        didRestore = true
      }
      .interactiveDismissDisabled(hasEdited || saving)
      .confirmationDialog(
        companionMapText("companion.place.unsavedTitle", "邀约还有未保存的修改"),
        isPresented: $showingCloseOptions, titleVisibility: .visible
      ) {
        Button(companionMapText("companion.place.save", "保存邀约草稿")) {
          Task { if await saveDraft() { onInviteSaved?(); dismiss() } }
        }
        Button(companionMapText("companion.place.discard", "放弃本次修改"), role: .destructive) { dismiss() }
        Button(companionMapText("companion.common.cancel", "取消"), role: .cancel) {}
      }

  }

  private var placeContent: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          hero
          VStack(alignment: .leading, spacing: 12) {
            Text(experience.shortName)
              .font(.system(.title, design: .serif).weight(.medium))
              .foregroundStyle(CompanionHomeStyle.ink)
              .fixedSize(horizontal: false, vertical: true)
            Text(companionMapText("companion.place.why", "为何值得去")).companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
            Text(experience.isUserCreated ? experience.oneLiner : summary).font(.body)
              .foregroundStyle(CompanionHomeStyle.secondaryInk)
              .fixedSize(horizontal: false, vertical: true)
            Text(companionMapText("companion.place.sourceUnverified", "收录资料 · 出发前请核实"))
              .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
              .fixedSize(horizontal: false, vertical: true)
            if let distance = CompanionPlacePresentation.distance(
              to: experience.coordinate, from: distanceOrigin, usesGPS: distanceUsesGPS)
            {
              Label(distance, systemImage: "location").companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
            }
            Button(action: openDirections) {
              Label(
                companionMapText("companion.place.directions", "步行导航"),
                systemImage: "arrow.triangle.turn.up.right.diamond"
              )
              .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(CompanionPlaceNavigationButtonStyle(isPrimary: !invitationExpanded))
            .disabled(experience.coordinate == nil)
          }
          DisclosureGroup(isExpanded: $invitationExpanded) {
            VStack(alignment: .leading, spacing: 18) {
              Button {
                choosingPeople = true
              } label: {
                HStack {
                  Label(companionMapText("companion.place.people", "和谁一起"), systemImage: "person.2")
                  Spacer()
                  Text(
                    selectedPeople.isEmpty
                      ? companionMapText("companion.people.solo", "这次自己走")
                      : selectedPeople.map(\.name).joined(separator: "、")
                  )
                  .foregroundStyle(CompanionHomeStyle.secondaryInk).multilineTextAlignment(.trailing)
                  Image(systemName: "chevron.right").companionMetadata()
                }.frame(minHeight: 44)
              }.foregroundStyle(.primary).accessibilityIdentifier("companion.place.people")
              DatePicker(companionMapText("companion.place.date", "出发时间"), selection: $date)
                .onChange(of: date) { _, _ in
                  saved = false
                }
              LabeledContent(
                companionMapText("companion.place.timeZone", "时区"),
                value: TimeZone.current.identifier
              )
              .companionMetadata()
              Picker(companionMapText("companion.place.duration", "预计停留"), selection: $duration) {
                ForEach([30, 60, 90, 120], id: \.self) { minutes in
                  Text("\(minutes) " + companionMapText("companion.place.minutes", "分钟")).tag(
                    minutes)
                }
              }.onChange(of: duration) { _, _ in
                saved = false
              }
              TextField(
                companionMapText("companion.place.note", "想一起做什么"), text: $note, axis: .vertical
              )
              .accessibilityIdentifier("companion.place.inviteNote")
              .lineLimit(2...5).onChange(of: note) { _, _ in
                saved = false
              }
              if date <= Date() {
                Label(
                  companionMapText("companion.place.past", "这个时间已经过去，请手动修改后再保存。"),
                  systemImage: "clock.badge.exclamationmark"
                )
                .foregroundStyle(.orange).companionMetadata()
              }
              Button {
                Task {
                  if await saveDraft() {
                    onInviteSaved?()
                    dismiss()
                  }
                }
              } label: {
                HStack {
                  if saving { ProgressView() }
                  Text(
                    saved
                      ? companionMapText("companion.place.saved", "已保存 · 未发送")
                      : companionMapText("companion.place.save", "保存邀约草稿"))
                }.frame(maxWidth: .infinity, minHeight: 44)
              }
              .buttonStyle(.borderedProminent).tint(CompanionHomeStyle.accent)
              .disabled(saving || date <= Date())
              .accessibilityIdentifier("companion.place.saveInvite")
              if let error = store.errorMessage {
                Text(error).companionMetadata().foregroundStyle(.red)
              }
              Text(
                companionMapText("companion.place.unsent", "草稿仅保存在本机，尚未发送，对方尚未确认。选择同行人不会共享任何位置。")
              )
              .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
              if hasEdited {
                Text(companionMapText("companion.place.unsavedHint", "修改尚未保存。请保存草稿，或点完成选择放弃修改。"))
                  .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
              }
            }.padding(.top, 18)
          } label: {
            Label(companionMapText("companion.place.invite", "约一次同行"), systemImage: "person.2")
              .font(.headline).foregroundStyle(CompanionHomeStyle.ink)
              .frame(minHeight: 44)
              .accessibilityIdentifier("companion.place.invite")
          }
          Divider()
          placeFacts
          DisclosureGroup(isExpanded: $sourcesExpanded) {
            VStack(alignment: .leading, spacing: 14) {
              Text(
                companionMapText(
                  "companion.place.notLiveVerified", "来源记录不等于本次实时核验；营业安排、收费和设施请向地点确认。")
              )
              .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
              if experience.sources.isEmpty {
                Text(companionMapText("companion.place.noSource", "暂无可核实来源，请在出发前确认。"))
              }
              ForEach(Array(experience.sources.enumerated()), id: \.offset) { _, source in
                VStack(alignment: .leading, spacing: 4) {
                  if let url = source.url, ["https", "http"].contains(url.scheme ?? "") {
                    Link(CompanionPlacePresentation.sourceName(source), destination: url)
                  } else {
                    Text(CompanionPlacePresentation.sourceName(source))
                  }
                  Text(companionMapText("companion.place.recordDate", "资料标注日期"))
                    .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
                  Text(source.verifiedAt, format: .dateTime.year().month().day())
                    .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
                }
              }
              if CompanionPlacePresentation.isChinese(experience.confidence.reason) {
                Text(experience.confidence.reason).companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
              }
              if chinese && !experience.isUserCreated {
                DisclosureGroup(isExpanded: $originalExpanded) {
                  VStack(alignment: .leading, spacing: 10) {
                    Text(experience.title)
                    Text(experience.oneLiner)
                    Text(experience.whyItMatters)
                    ForEach(experience.howTo) { step in Text(step.text) }
                    ForEach(Array(experience.realInconveniences.enumerated()), id: \.offset) {
                      _, item in Text(item.text)
                    }
                  }.companionMetadata().padding(.top, 8)
                } label: {
                  Text(companionMapText("companion.place.original", "查看资料原文"))
                }
              }

            }.padding(.top, 12)
          } label: {
            Label(
              companionMapText("companion.place.sources", "来源与核实"), systemImage: "text.book.closed"
            )
            .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
            .frame(minHeight: 44)
          }
        }
        .padding(CompanionHomeStyle.inset)
      }
      .background(CompanionHomeStyle.paper)
      .scrollDismissesKeyboard(.interactively)
      .tint(CompanionHomeStyle.accent)
      .navigationDestination(isPresented: $choosingPeople) {
        CompanionPeopleSheet(store: store, isEmbedded: true, initialPeople: localPeople) { people in
          localPeople = people
          saved = false
        }
      }
      .navigationTitle(experience.shortName).navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        HStack {
          Spacer()
          Button {
            guard hasEdited else { dismiss(); return }
            showingCloseOptions = true
          } label: {
            Text(companionMapText("companion.common.done", "完成"))
              .font(.body.weight(.semibold))
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
              .padding(.horizontal, 12)
          }
          .buttonStyle(.plain)
          .disabled(saving).accessibilityIdentifier("companion.place.close")
        }
        .padding(.horizontal, CompanionHomeStyle.inset).padding(.vertical, 4)
        .foregroundStyle(CompanionHomeStyle.ink)
        .background(CompanionHomeStyle.paper)
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            preferences.toggleFavorite(experience.id)
          } label: {
            Image(systemName: preferences.favoritedExperiences.contains(experience.id) ? "heart.fill" : "heart")
              .frame(minWidth: 44, minHeight: 44)
          }
          .accessibilityLabel(
            preferences.favoritedExperiences.contains(experience.id)
              ? companionMapText("companion.place.unsave", "取消收藏")
              : companionMapText("companion.place.favorite", "收藏地点")
          )
          .accessibilityIdentifier("companion.place.favorite")
        }
      }
    }
  }

  private var placeFacts: some View {
    DisclosureGroup {
      VStack(alignment: .leading, spacing: 14) {
        if let address = experience.location.addressHint, !address.isEmpty {
          LabeledContent(
            companionMapText("companion.place.addressOriginal", "地址（保留原文便于导航）"), value: address)
        } else {
          Text(companionMapText("companion.place.addressMissing", "详细地址待补充，可先查看地图落点。"))
        }
        if let hours = experience.location.openingHours, !hours.isEmpty {
          LabeledContent(companionMapText("companion.place.hours", "营业时间（资料标注）"), value: hours)
        } else {
          Text(companionMapText("companion.place.hoursMissing", "营业时间尚未收录，出发前请确认。"))
        }
        if let price = experience.location.priceLevel, price >= 1, price <= 4 {
          LabeledContent(
            companionMapText("companion.place.price", "价格档位（资料标注）"), value: "\(Int(price))/4")
        } else {
          Text(companionMapText("companion.place.priceMissing", "价格尚未收录。"))
        }
        if let raw = experience.location.website, let url = URL(string: raw),
          ["https", "http"].contains(url.scheme ?? "")
        {
          Link(companionMapText("companion.place.website", "查看地点网站"), destination: url)
            .frame(minHeight: 44)
        }
      }.font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk).padding(.top, 12)
    } label: {
      Label(companionMapText("companion.place.facts", "地址与营业资料"), systemImage: "info.circle")
        .font(.subheadline).frame(minHeight: 44)
    }
  }

  @ViewBuilder
  private var hero: some View {
    if experience.isUserCreated, let raw = experience.location.photoUrls?.first,
      let url = URL(string: raw), url.isFileURL, let image = UIImage(contentsOfFile: url.path)
    {
      VStack(alignment: .leading, spacing: 7) {
        Image(uiImage: image).resizable().scaledToFill()
          .frame(maxWidth: .infinity).frame(height: 210).clipped()
          .clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
        Text(companionMapText("companion.place.userPhoto", "用户添加的照片 · 拍摄地点未核实"))
          .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
      }
    } else if let raw = experience.location.photoUrls?.first,
      let url = URL(string: raw), ["https", "http"].contains(url.scheme ?? ""),
      !isAtmospherePhoto(url)
    {
      VStack(alignment: .leading, spacing: 7) {
        AsyncImage(url: url) { phase in
          if let image = phase.image {
            image.resizable().scaledToFill()
          } else {
            categoryPlaceholder
          }
        }
        .frame(maxWidth: .infinity).frame(height: 210).clipped()
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityHidden(true)
        Text(photoCredit(url)).companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
      }
    } else {
      HStack(spacing: 10) {
        Image(systemName: experience.category.symbol)
          .font(.body).foregroundStyle(CompanionHomeStyle.accent)
          .accessibilityHidden(true)
        Text(companionMapText("companion.place.noVerifiedPhoto", "暂无可核实的地点照片"))
          .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
      }
      .padding(.vertical, 4)
    }
  }

  private func isAtmospherePhoto(_ url: URL) -> Bool {
    let host = url.host?.lowercased() ?? ""
    return host == "unsplash.com" || host.hasSuffix(".unsplash.com")
  }

  private func photoCredit(_ url: URL) -> String {
    let host = url.host?.lowercased() ?? ""
    if host == "unsplash.com" || host.hasSuffix(".unsplash.com") {
      return companionMapText("companion.place.photoAtmosphere", "氛围参考 · Unsplash")
    }
    return companionMapText("companion.place.photoReference", "资料配图 · 拍摄地点未核实")
  }

  private var categoryPlaceholder: some View {
    ZStack {
      CompanionHomeStyle.accent.opacity(0.08)
      Image(systemName: experience.category.symbol)
        .font(.system(size: 44, weight: .ultraLight))
        .foregroundStyle(CompanionHomeStyle.accent.opacity(0.6))
    }
  }

  private func openDirections() {
    guard let coordinate = experience.coordinate else { return }
    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    item.name = experience.shortName
    item.openInMaps(launchOptions: [
      MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
    ])
  }

  private func restoreDraft() {
    if let draft = store.invites.last(where: { $0.placeID == experience.id && $0.status == .draft }) {
      inviteID = draft.id
      date = draft.date
      duration = draft.durationMinutes
      note = draft.note
      localPeople = draft.people
    } else {
      localPeople = store.people.filter { store.selectedPeopleIDs.contains($0.id) }
    }
    originalDraft = makeDraft()
  }

  private func makeDraft() -> CompanionHomeInvite {
    CompanionHomeInvite(
      id: inviteID, placeID: experience.id,
      placeName: experience.shortName, date: date, durationMinutes: duration,
      people: selectedPeople, note: note, status: .draft)
  }

  @discardableResult
  private func saveDraft() async -> Bool {
    guard !saving else { return false }
    guard date > Date() else { invitationExpanded = true; return false }
    saving = true
    store.clearError()
    saved = await store.saveInvite(makeDraft())
    saving = false
    if saved { originalDraft = makeDraft() }
    else { invitationExpanded = true }
    return saved
  }
}

private struct CompanionPlaceNavigationButtonStyle: ButtonStyle {
  let isPrimary: Bool
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.body.weight(.medium))
      .foregroundStyle(isPrimary ? CompanionHomeStyle.paper : CompanionHomeStyle.ink)
      .padding(.horizontal, 16).padding(.vertical, 4)
      .background(
        isPrimary ? CompanionHomeStyle.ink : CompanionHomeStyle.accent.opacity(0.08),
        in: RoundedRectangle(cornerRadius: 16)
      )
      .opacity(configuration.isPressed ? 0.72 : 1)
  }
}
