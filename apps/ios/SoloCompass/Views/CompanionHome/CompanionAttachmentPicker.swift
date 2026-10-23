import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

@MainActor
struct CompanionAttachmentPicker: View {
    let store: CompanionHomeStore
    let onRecord: () -> Void
    @Environment(ExperienceService.self) private var experiences
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var showCamera = false
    @State private var places = false
    @State private var favorites = false
    @State private var search = ""
    @State private var importing = false
    @State private var importTask: Task<Void, Never>?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if places { placeList } else { actions }
            }
            .navigationTitle(places ? companionText("companion.media.choosePlace", "选择地点") : companionText("companion.media.add", "添加内容"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(companionText("companion.cancel", "取消")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if importing {
                    HStack {
                        ProgressView()
                        Text(companionText("companion.media.importing", "正在准备原件…")).font(.subheadline)
                        Spacer()
                        Button(companionText("companion.cancel", "取消")) { importTask?.cancel(); importing = false }
                    }.padding().background(.regularMaterial)
                } else if let error {
                    Text(error).font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk).padding()
                }
            }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photo, matching: .images)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { prepare { try await CompanionMediaPreparation.file(url) } }
            case .failure: error = companionText("companion.media.importFailed", "未能读取这个文件，草稿仍在。可以重新选择。")
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                guard let data = image?.jpegData(compressionQuality: 0.9) else { return }
                prepare { try await CompanionMediaPreparation.image(data) }
            }.ignoresSafeArea()
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            prepare {
                guard let bytes = try await item.loadTransferable(type: Data.self) else { throw CompanionMediaPreparation.Failure.invalidFile }
                return try await CompanionMediaPreparation.image(bytes)
            }
        }
        .onDisappear { importTask?.cancel() }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var actions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                action("photo", "companion.media.photos", "照片") { showPhotos = true }
                action("camera", "companion.media.camera", "拍照") {
                    Task {
                        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                            error = companionText("companion.media.cameraUnavailable", "当前设备没有可用相机，可以从照片中选择。")
                            return
                        }
                        let permitted = await AVCaptureDevice.requestAccess(for: .video)
                        if permitted { showCamera = true }
                        else { error = companionText("companion.media.cameraDenied", "未开启相机权限，仍可从照片中选择。") }
                    }
                }
                action("mic", "companion.media.voice", "语音消息") {
                    guard store.canStartRecording else { error = companionText("companion.media.recordLimit", "请先移除一份附件，或导出本机媒体后再录音。" ); return }
                    dismiss(); onRecord()
                }
                action("doc", "companion.media.files", "文件或已有音频") { showFiles = true }
                action("mappin.and.ellipse", "companion.media.place", "地点") { places = true }
                Text(companionText("companion.media.localHint", "原件保存在本机。发送后仅提供可识别文字、转写或所选地点资料；未提取的画面和文件内容不会被读取。"))
                    .font(.footnote).foregroundStyle(CompanionHomeStyle.secondaryInk).padding(.horizontal, 16).padding(.top, 14)
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }.background(CompanionHomeStyle.paper)
    }
    private func action(_ icon: String, _ key: String, _ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(companionText(key, title), systemImage: icon).font(.body)
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading).padding(.horizontal, 16).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(importing).accessibilityIdentifier(key)
    }
    private var matchingPlaces: [Experience] {
        let candidates = favorites ? experiences.allExperiences.filter { preferences.favoritedExperiences.contains($0.id) } : experiences.filteredExperiences.filter { CompanionMediaPlaceScope.includes($0, cityCode: store.selectedSearchArea?.cityCode) }
        return candidates.filter { search.isEmpty || $0.shortName.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search) }
    }
    private var placeList: some View {
        List {
            if !favorites, let area = store.selectedSearchArea { Text(area.name).font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk) }
            Toggle(companionText("companion.media.favoritesOnly", "只看收藏"), isOn: $favorites)
            ForEach(matchingPlaces) { place in
                Button {
                    guard let coordinate = place.coordinate else { return }
                    let media = CompanionMediaAttachment(kind: .place, name: place.shortName, mimeType: "application/x-roamorrow-place",
                        place: .init(experienceID: place.id, name: place.shortName,
                                     latitude: coordinate.latitude, longitude: coordinate.longitude))
                    if store.stageAttachment(media) { dismiss() }
                    else { error = store.errorMessage }
                } label: {
                    Label(place.shortName, systemImage: "mappin").font(.body).padding(.vertical, 8)
                }.accessibilityIdentifier("companion.media.pickPlace.\(place.id)")
            }
            if matchingPlaces.isEmpty { Text(companionText("companion.media.noPlaces", "这里暂时没有地点，可切换城市或关闭收藏筛选。")) }
        }.searchable(text: $search, prompt: companionText("companion.media.placeSearch", "搜索当前范围的地点"))
    }
    private func prepare(_ operation: @escaping () async throws -> CompanionMediaAttachment) {
        importTask?.cancel(); importing = true; error = nil
        importTask = Task {
            defer { importing = false }
            do {
                let attachment = try await operation()
                try Task.checkCancellation()
                if store.stageAttachment(attachment) { dismiss() }
                else { error = store.errorMessage }
            } catch {
                if !Task.isCancelled { self.error = companionText("companion.media.importFailed", "未能读取这个文件，草稿仍在。可以重新选择。") }
            }
        }
    }
}

@MainActor
enum CompanionMediaPlaceScope {
    static func includes(_ experience: Experience, cityCode: String?) -> Bool {
        guard let cityCode else { return true }
        return MapViewModel.cityCodeMatches(experience.location.cityCode, selected: cityCode)
    }
}
