import SwiftUI

@MainActor
struct CompanionCitySheet: View {
  @Bindable var model: MapViewModel
  var onSelectCity: (() -> Void)? = nil
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(
            model.availableCities.filter { city in
              query.isEmpty || city.name.localizedCaseInsensitiveContains(query)
                || city.code.localizedCaseInsensitiveContains(query)
                || CompanionPlacePresentation.cityName(code: city.code, fallback: city.name)
                  .localizedCaseInsensitiveContains(query)
            }, id: \.code
          ) { city in
            Button {
              onSelectCity?()
              model.selectCity(city.code)
              dismiss()
            } label: {
              HStack {
                Text(CompanionPlacePresentation.cityName(code: city.code, fallback: city.name))
                Spacer()
                if model.selectedCity == city.code { Image(systemName: "checkmark") }
              }.frame(minHeight: 44)
            }.foregroundStyle(CompanionHomeStyle.ink)
              .accessibilityIdentifier("companion.city.option.\(city.code)")
              .accessibilityAddTraits(model.selectedCity == city.code ? .isSelected : [])
          }
        } footer: {
          Text(companionMapText("companion.city.scope", "搜索已收录的城市。切换后地图移至该城市，你的原话和邀约草稿会保留。"))
        }
      }
      .safeAreaInset(edge: .top) {
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass").foregroundStyle(CompanionHomeStyle.secondaryInk)
          TextField(companionMapText("companion.city.search", "搜索已收录城市"), text: $query)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .submitLabel(.search).accessibilityIdentifier("companion.city.search")
          if !query.isEmpty {
            Button {
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
            }
            .frame(width: 44, height: 44)
            .accessibilityLabel(companionMapText("companion.city.clear", "清除搜索"))
          }
        }
        .frame(minHeight: 44).padding(.horizontal, 14)
        .background(
          Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14)
        )
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(CompanionHomeStyle.paper)
      }
      .overlay {
        if !query.isEmpty
          && !model.availableCities.contains(where: {
            $0.name.localizedCaseInsensitiveContains(query)
              || $0.code.localizedCaseInsensitiveContains(query)
              || CompanionPlacePresentation.cityName(code: $0.code, fallback: $0.name)
                .localizedCaseInsensitiveContains(query)
          })
        {
          ContentUnavailableView.search(text: query)
        }
      }
      .navigationTitle(companionMapText("companion.city.title", "选择城市"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(companionMapText("companion.common.cancel", "取消")) { dismiss() }
            .accessibilityIdentifier("companion.city.cancel")
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}
