import SwiftUI
import PhotosUI

/// Life Studio is a local-first front door; the existing map still owns travel services.
struct StudioHomeView: View {
    @Environment(NotificationService.self) private var notifications
    @State private var store = StudioStore()
    @State private var selection: StudioPiece?
    @State private var sheet: StudioSheet?
    @State private var photo: PhotosPickerItem?
    @State private var useAsBackground = false
    @State private var importing = false
    @State private var showPicker = false
    @State private var showMap = false
    @State private var showReset = false
    @State private var importError: String?
    @State private var exportImage: UIImage?
    @State private var pendingPhotoBackground: Bool?
    @State private var pendingPiece: StudioPiece?

    private enum StudioSheet: String, Identifiable { case collect, account, share, title; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    introduction
                    canvas
                    canvasTools
                    collection
                    exploreInvitation
                }
                .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 24)
            }
            .background(StudioStyle.paper)
            .foregroundStyle(StudioStyle.ink)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { collectBar }
        }
        .tint(StudioStyle.ink)
        .preferredColorScheme(.light)
        .sheet(item: $sheet, onDismiss: finishSheet) { destination in
            switch destination {
            case .collect: collectSheet
            case .account: MeSheet()
            case .share:
                if let exportImage { StudioShareSheet(image: exportImage) }
            case .title: titleSheet
            }
        }
        .sheet(item: $selection) { piece in
            StudioPieceEditor(piece: piece, store: store)
        }
        .photosPicker(isPresented: $showPicker, selection: $photo, matching: .images)
        .task(id: photo) { await importPhoto() }
        .fullScreenCover(isPresented: $showMap) {
            CompassMapView()
                .overlay(alignment: .topLeading) {
                    Button { showMap = false } label: {
                        Label("studio.back", systemImage: "arrow.left").font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14).padding(.vertical, 11).background(.regularMaterial, in: Capsule())
                    }.padding(.leading, 16).padding(.top, 4)
                }
        }
        .onChange(of: notifications.pendingDeepLink, initial: true) { _, value in
            if value != nil { sheet = nil; selection = nil; showMap = true }
        }
        .alert("studio.error.title", isPresented: Binding(
            get: { importError != nil || store.error != nil },
            set: { if !$0 { importError = nil; store.clearError() } }
        )) {
            Button("studio.ok", role: .cancel) { importError = nil; store.clearError() }
        } message: { Text(importError ?? store.error ?? "") }
        .confirmationDialog("studio.reset.confirm", isPresented: $showReset, titleVisibility: .visible) {
            Button("studio.reset", role: .destructive) { store.change { $0 = StudioDocument() } }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 9) {
                Image(systemName: "leaf").font(.system(size: 24, weight: .ultraLight))
                Text("studio.brand").font(.system(size: 24, weight: .medium, design: .serif)).tracking(3)
            }
            Spacer()
            Button { sheet = .account } label: {
                Image(systemName: "person.crop.circle").font(.system(size: 23, weight: .ultraLight)).frame(width: 44, height: 44)
            }.accessibilityLabel(Text("studio.account"))
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("studio.collection_tagline").font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(2.5).foregroundStyle(StudioStyle.accent)
            Text("studio.headline").font(.system(size: 29, weight: .regular, design: .serif)).lineSpacing(5)
            Text("studio.subtitle").font(.system(size: 13)).foregroundStyle(StudioStyle.ink.opacity(0.65)).lineSpacing(4)
        }
    }

    private var canvas: some View {
        ZStack {
            StudioCanvas(document: store.document, onSelect: { selection = $0 }, onMove: store.move)
            if store.document.pieces.isEmpty && store.document.background == nil {
                VStack(spacing: 18) {
                    Image(systemName: "plus.viewfinder").font(.system(size: 36, weight: .ultraLight))
                    Text("studio.empty.title").font(.system(size: 21, design: .serif))
                    Text("studio.empty.body").font(.system(size: 13)).multilineTextAlignment(.center).lineSpacing(5)
                    Button { store.addSample() } label: {
                        Label("studio.sample.action", systemImage: "arrow.up.right")
                            .font(.system(size: 12, weight: .medium)).padding(.vertical, 12).padding(.horizontal, 18)
                            .overlay(Capsule().stroke(StudioStyle.ink.opacity(0.25)))
                    }
                }.padding(30)
            }
        }
        .clipShape(.rect(cornerRadius: 3))
    }

    private var canvasTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { sheet = .title } label: {
                    HStack(spacing: 6) {
                        Text(store.document.title.isEmpty ? String(localized: "studio.untitled") : store.document.title)
                            .font(.system(size: 16, design: .serif)).lineLimit(1)
                        Image(systemName: "pencil").font(.system(size: 10))
                    }
                }
                Spacer()
                Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 40, height: 44) }
                    .disabled(store.history.isEmpty).accessibilityLabel(Text("studio.undo"))
                Button(action: export) { Image(systemName: "square.and.arrow.up").frame(width: 40, height: 44) }
                    .disabled(store.document.pieces.isEmpty && store.document.background == nil)
                    .accessibilityLabel(Text("studio.share"))
            }
            HStack(spacing: 11) {
                ForEach(StudioStyle.surfaces.indices, id: \.self) { index in
                    Button { store.change { $0.paper = index; $0.background = nil } } label: {
                        Circle().fill(StudioStyle.surfaces[index]).frame(width: 22, height: 22)
                            .padding(5).overlay(Circle().stroke(store.document.paper == index && store.document.background == nil ? StudioStyle.ink : .clear))
                    }.accessibilityLabel(Text("studio.paper.\(index)"))
                }
                Spacer()
                Text("studio.canvas.hint").font(.system(size: 11)).foregroundStyle(StudioStyle.ink.opacity(0.6))
            }
        }
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 13) {
            Divider()
            HStack {
                Text("studio.collection").font(.system(size: 17, design: .serif))
                Spacer()
                Text(String(format: String(localized: "studio.count"), store.document.pieces.count))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(StudioStyle.ink.opacity(0.55))
            }
            if !store.document.pieces.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(store.document.pieces) { piece in
                            Button { selection = piece } label: {
                                VStack(spacing: 8) {
                                    StudioPieceArtwork(piece: piece).frame(width: 120).scaleEffect(0.4)
                                        .frame(width: 82, height: 85).clipped().background(.white.opacity(0.55))
                                    Text(piece.title).font(.system(size: 11)).lineLimit(1).frame(width: 82)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("studio.collection.empty").font(.system(size: 13)).foregroundStyle(StudioStyle.ink.opacity(0.6))
            }
        }
    }

    private var exploreInvitation: some View {
        Button { showMap = true } label: {
            HStack(spacing: 16) {
                Image(systemName: "map").font(.system(size: 25, weight: .ultraLight))
                VStack(alignment: .leading, spacing: 5) {
                    Text("studio.explore").font(.system(size: 15, design: .serif))
                    Text("studio.explore.body").font(.system(size: 11)).foregroundStyle(StudioStyle.ink.opacity(0.6))
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 13))
            }.padding(.vertical, 20)
        }
    }

    private var collectBar: some View {
        HStack(spacing: 16) {
            Button { showMap = true } label: {
                Image(systemName: "map").font(.system(size: 20, weight: .light)).frame(width: 48, height: 50)
            }.accessibilityLabel(Text("studio.explore"))
            Button { sheet = .collect } label: {
                HStack(spacing: 9) {
                    if importing { ProgressView().tint(.white) } else { Image(systemName: "plus") }
                    Text(importing ? "studio.importing" : "studio.collect")
                }.font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(StudioStyle.ink, in: Capsule())
            }.disabled(importing || !store.isReadable)
            Menu {
                Button("studio.reset", role: .destructive) { showReset = true }
            } label: { Image(systemName: "ellipsis").frame(width: 40, height: 50) }
                .accessibilityLabel(Text("studio.more"))
        }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 5)
            .background(StudioStyle.paper.opacity(0.98))
    }

    private var collectSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button { choosePhoto(background: false) } label: {
                        Label("studio.add.photo", systemImage: "photo")
                    }
                    Button { choosePhoto(background: true) } label: {
                        Label("studio.add.scenery", systemImage: "mountain.2")
                    }
                    Button { add(.book) } label: { Label("studio.add.book", systemImage: "book.closed") }
                    Button { add(.note) } label: { Label("studio.add.note", systemImage: "note.text") }
                } footer: { Text("studio.local") }
            }
            .navigationTitle("studio.collect")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("studio.done") { sheet = nil } } }
        }.presentationDetents([.medium, .large])
    }

    private var titleSheet: some View {
        StudioTitleEditor(title: store.document.title) { title in
            store.change { $0.title = title }
        }
    }

    private func choosePhoto(background: Bool) {
        pendingPhotoBackground = background
        sheet = nil
    }

    private func finishSheet() {
        if let background = pendingPhotoBackground {
            pendingPhotoBackground = nil
            useAsBackground = background
            showPicker = true
        } else if let piece = pendingPiece {
            pendingPiece = nil
            selection = piece
        }
    }

    private func add(_ kind: StudioPiece.Kind) {
        let title = String(localized: kind == .book ? "studio.book.default" : "studio.note.default")
        let piece = StudioPiece(kind: kind, title: title)
        guard store.change({ $0.pieces.append(piece) }) else { return }
        pendingPiece = piece
        sheet = nil
    }

    @MainActor private func importPhoto() async {
        guard let item = photo else { return }
        importing = true
        defer { importing = false; photo = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadUnknown) }
            try Task.checkCancellation()
            let normalized = try await Task.detached(priority: .userInitiated) { try StudioMedia.normalized(data) }.value
            try Task.checkCancellation()
            if useAsBackground { store.change { $0.background = normalized } }
            else {
                var piece = StudioPiece(kind: .photo, title: String(localized: "studio.photo.default"))
                piece.original = normalized
                if store.change({ $0.pieces.append(piece) }) { selection = piece }
            }
        } catch is CancellationError { }
        catch { importError = String(localized: "studio.error.import") }
    }

    @MainActor private func export() {
        let renderer = ImageRenderer(content:
            VStack(alignment: .leading, spacing: 18) {
                StudioCanvas(document: store.document, interactive: false).frame(width: 600)
                Text(store.document.title.isEmpty ? String(localized: "studio.untitled") : store.document.title)
                    .font(.system(size: 23, design: .serif))
                Text("studio.export.signature").font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(26).background(StudioStyle.paper).foregroundStyle(StudioStyle.ink)
        )
        renderer.scale = 2
        guard let image = renderer.uiImage else { importError = String(localized: "studio.error.export"); return }
        exportImage = image
        sheet = .share
    }
}

private struct StudioTitleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var title: String
    var save: (String) -> Void
    var body: some View {
        NavigationStack {
            Form { TextField("studio.title.placeholder", text: $title) }
                .navigationTitle("studio.title.edit")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("studio.cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("studio.done") { save(title); dismiss() } }
                }
        }.presentationDetents([.medium])
    }
}

struct StudioShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
