import SwiftUI

/// A intentionally small palette; materials and object geometry remain independently editable.
enum StudioStyle {
    static let ink = Color(red: 0.23, green: 0.28, blue: 0.25)
    static let accent = Color(red: 0.55, green: 0.29, blue: 0.20)
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let surfaces: [Color] = [
        Color(red: 0.91, green: 0.89, blue: 0.83),
        Color(red: 0.81, green: 0.85, blue: 0.80),
        Color(red: 0.87, green: 0.81, blue: 0.76)
    ]
    static let covers: [Color] = [
        Color(red: 0.35, green: 0.43, blue: 0.37),
        Color(red: 0.60, green: 0.34, blue: 0.25),
        Color(red: 0.34, green: 0.41, blue: 0.49)
    ]
}

struct StudioCanvas: View {
    let document: StudioDocument
    var interactive = true
    var onSelect: (StudioPiece) -> Void = { _ in }
    var onMove: (UUID, Double, Double) -> Void = { _, _, _ in }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                StudioStyle.surfaces[document.paper % StudioStyle.surfaces.count]
                if let data = document.background, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    // A quiet paper border is UI chrome, not a simulated room asset.
                    Rectangle().strokeBorder(StudioStyle.ink.opacity(0.12), lineWidth: 1)
                        .padding(18)
                    VStack {
                        HStack {
                            Text("studio.collection_stamp").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(2)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "leaf").font(.system(size: 14, weight: .ultraLight))
                        }
                    }.padding(30).foregroundStyle(StudioStyle.ink.opacity(0.42))
                }
                ForEach(document.pieces) { piece in
                    StudioMovablePiece(piece: piece, size: geometry.size, interactive: interactive,
                                       onSelect: onSelect, onMove: onMove)
                }
            }
            .clipped()
        }
        .aspectRatio(0.82, contentMode: .fit)
        .accessibilityIdentifier("studio.canvas")
    }
}

private struct StudioMovablePiece: View {
    let piece: StudioPiece
    let size: CGSize
    let interactive: Bool
    let onSelect: (StudioPiece) -> Void
    let onMove: (UUID, Double, Double) -> Void
    @GestureState private var translation = CGSize.zero

    var body: some View {
        StudioPieceArtwork(piece: piece)
            .frame(width: size.width * 0.38)
            .scaleEffect(piece.scale)
            .rotationEffect(.degrees(piece.angle))
            .shadow(color: .black.opacity(piece.kind == .photo ? 0.10 : 0.14), radius: 9, x: 2, y: 8)
            .position(x: piece.x * size.width + translation.width, y: piece.y * size.height + translation.height)
            .onTapGesture { if interactive { onSelect(piece) } }
            .gesture(DragGesture(minimumDistance: 5)
                .updating($translation) { value, state, _ in if interactive { state = value.translation } }
                .onEnded { value in
                    guard interactive else { return }
                    onMove(piece.id, piece.x + value.translation.width / size.width,
                           piece.y + value.translation.height / size.height)
                }, including: interactive ? .all : .none)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(piece.title)
            .accessibilityHint(Text("studio.piece.hint"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onSelect(piece) }
    }
}

struct StudioPieceArtwork: View {
    let piece: StudioPiece

    var body: some View {
        switch piece.kind {
        case .coffee:
            Image("StudioCoffee").resizable().scaledToFit()
        case .photo:
            if let data = piece.cutout ?? piece.original, let image = UIImage(data: data) {
                if piece.cutout != nil {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    VStack(spacing: 8) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(height: 130).clipped()
                        if !piece.title.isEmpty {
                            Text(piece.title).font(.system(size: 11, design: .serif)).lineLimit(2)
                        }
                    }.padding(9).padding(.bottom, 5).background(.white)
                }
            }
        case .book:
            ZStack(alignment: .leading) {
                StudioStyle.covers[piece.color % StudioStyle.covers.count]
                Rectangle().fill(.black.opacity(0.15)).frame(width: 9)
                VStack(alignment: .leading, spacing: 12) {
                    Text(piece.title).font(.system(size: 21, weight: .regular, design: .serif))
                        .lineLimit(5).minimumScaleFactor(0.65)
                    Rectangle().fill(.white.opacity(0.45)).frame(width: 23, height: 1)
                    Spacer(minLength: 4)
                    Text(piece.detail).font(.system(size: 8, design: .monospaced)).tracking(1).lineLimit(3)
                }.padding(.vertical, 20).padding(.leading, 22).padding(.trailing, 12)
                    .foregroundStyle(Color(red: 0.95, green: 0.92, blue: 0.82))
            }
            .frame(height: 192)
            .clipShape(.rect(cornerRadius: 2))
            .overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.6)).frame(width: 3).padding(.vertical, 3) }
        case .note:
            Text(piece.title).font(.system(size: 17, design: .serif)).lineSpacing(7)
                .lineLimit(7).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .padding(18)
                .background(Color(red: 0.98, green: 0.95, blue: 0.83))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.45)).frame(width: 42, height: 14).offset(y: -7)
                }
        }
    }
}
