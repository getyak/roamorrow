import SwiftUI

struct StudioPieceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var piece: StudioPiece
    let store: StudioStore
    @State private var extracting = false
    @State private var extractionError = false
    @State private var extractionTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        StudioPieceArtwork(piece: piece).frame(width: 140).padding(.vertical, 12)
                        Spacer()
                    }.listRowBackground(StudioStyle.surfaces[0])
                }
                Section("studio.editor.story") {
                    TextField("studio.editor.title", text: $piece.title, axis: .vertical).lineLimit(2...5)
                    TextField("studio.editor.detail", text: $piece.detail, axis: .vertical).lineLimit(1...4)
                }
                Section("studio.editor.arrange") {
                    LabeledContent("studio.editor.size", value: "\(Int(piece.scale * 100))%")
                    Slider(value: $piece.scale, in: 0.5...1.6, step: 0.05).accessibilityLabel(Text("studio.editor.size"))
                    LabeledContent("studio.editor.angle", value: "\(Int(piece.angle))°")
                    Slider(value: $piece.angle, in: -45...45, step: 1).accessibilityLabel(Text("studio.editor.angle"))
                    // Alternative to dragging for VoiceOver and precise placement.
                    LabeledContent("studio.editor.horizontal", value: "\(Int(piece.x * 100))%")
                    Slider(value: $piece.x, in: 0.15...0.85).accessibilityLabel(Text("studio.editor.horizontal"))
                    LabeledContent("studio.editor.vertical", value: "\(Int(piece.y * 100))%")
                    Slider(value: $piece.y, in: 0.15...0.85).accessibilityLabel(Text("studio.editor.vertical"))
                    if piece.kind == .book {
                        Picker("studio.editor.cover", selection: $piece.color) {
                            Text("studio.cover.green").tag(0)
                            Text("studio.cover.clay").tag(1)
                            Text("studio.cover.blue").tag(2)
                        }
                    }
                }
                if piece.kind == .photo, piece.original != nil {
                    Section {
                        if piece.cutout != nil {
                            Button("studio.editor.original") { piece.cutout = nil }
                        } else {
                            Button(action: extract) {
                                HStack {
                                    Label("studio.editor.extract", systemImage: "person.crop.rectangle")
                                    Spacer()
                                    if extracting { ProgressView() }
                                }
                            }.disabled(extracting)
                        }
                    } footer: { Text("studio.editor.extract.body") }
                }
                Section {
                    Button("studio.editor.front") {
                        if store.change({ draft in
                            draft.pieces.removeAll { $0.id == piece.id }
                            draft.pieces.append(piece)
                        }) { dismiss() }
                    }
                    Button("studio.editor.delete", role: .destructive) {
                        if store.change({ $0.pieces.removeAll { $0.id == piece.id } }) { dismiss() }
                    }
                } footer: { Text("studio.editor.undo.body") }
            }
            .navigationTitle("studio.editor.heading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("studio.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("studio.done") {
                        if store.change({ draft in
                            if let index = draft.pieces.firstIndex(where: { $0.id == piece.id }) { draft.pieces[index] = piece }
                        }) { dismiss() }
                    }.disabled(extracting)
                }
            }
        }
        .tint(StudioStyle.ink)
        .onDisappear { extractionTask?.cancel() }
        .alert("studio.error.extract", isPresented: $extractionError) { Button("studio.ok", role: .cancel) {} }
    }

    private func extract() {
        guard let data = piece.original else { return }
        extracting = true
        extractionTask = Task { @MainActor in
            defer { extracting = false }
            do {
                let output = try await Task.detached(priority: .userInitiated) { try StudioMedia.foreground(data) }.value
                try Task.checkCancellation()
                piece.cutout = output
            } catch is CancellationError { }
            catch { extractionError = true }
        }
    }
}
