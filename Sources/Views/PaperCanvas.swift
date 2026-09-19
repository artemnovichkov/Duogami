import SwiftUI

enum WorkshopStyle {
    static let background = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let ink = Color(red: 0.23, green: 0.25, blue: 0.22)
    static let secondary = Color(red: 0.47, green: 0.48, blue: 0.43)
    static let accent = Color(red: 0.38, green: 0.44, blue: 0.32)
}

extension PaperTint {
    var color: Color {
        switch self {
        case .ochre: Color(red: 0.77, green: 0.60, blue: 0.34)
        case .clay: Color(red: 0.73, green: 0.42, blue: 0.32)
        case .sage: Color(red: 0.52, green: 0.62, blue: 0.47)
        case .blue: Color(red: 0.42, green: 0.56, blue: 0.66)
        }
    }
}

struct WorkbenchBackground: View {
    var body: some View {
        WorkshopStyle.background.overlay {
            Canvas { context, size in
                // Deterministic fine grain; no bitmap assets or random redraw flicker.
                for i in 0..<1800 {
                    let x = Double((i * 137 + 19) % 997) / 997 * size.width
                    let y = Double((i * 251 + 73) % 991) / 991 * size.height
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)), with: .color(.brown.opacity(0.07)))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

struct PaperCanvas: View, Animatable {
    var paper: PaperState
    var tint: PaperTint
    var operation: PaperOperation? = nil
    var progress = 0.0
    var rotation = 0.0
    var translation = PaperPoint(x: 0, y: 0)
    var showGuide = false
    var face: PatternFace? = nil
    var origin: CGPoint? = nil
    var horizontalHinge = false
    var fitToContent = false

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, AnimatablePair<Double, Double>>> {
        get { .init(progress, .init(rotation, .init(translation.x, translation.y))) }
        set {
            progress = newValue.first
            rotation = newValue.second.first
            translation = .init(x: newValue.second.second.first, y: newValue.second.second.second)
        }
    }

    var body: some View {
        let paperColor = tint.color
        return Canvas { context, size in
            let vertices = paper.faces.flatMap(\.points)
            let minX = vertices.map(\.x).min() ?? -1, maxX = vertices.map(\.x).max() ?? 1
            let minY = vertices.map(\.y).min() ?? -1, maxY = vertices.map(\.y).max() ?? 1
            let scale = fitToContent
                ? min(size.width / max(maxX - minX, 0.1), size.height / max(maxY - minY, 0.1)) * 0.7
                : min(size.width, size.height) * 0.43
            let paperCenter = fitToContent ? PaperPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2) : PaperPoint(x: 0, y: 0)
            let center = origin ?? CGPoint(x: size.width / 2, y: size.height / 2)
            func screen(_ point: PaperPoint, lift: Double = 0) -> CGPoint {
                let positioned = (point - paperCenter).rotated(rotation) + translation
                let p = horizontalHinge ? positioned.rotated(.pi / 2) : positioned
                return CGPoint(x: center.x + p.x * scale, y: center.y + p.y * scale - lift * scale * 0.18)
            }
            func path(_ points: [PaperPoint], lift: [Double] = []) -> Path {
                Path { p in
                    for (i, point) in points.enumerated() {
                        let position = screen(point, lift: lift.isEmpty ? 0 : lift[i])
                        if i == 0 { p.move(to: position) } else { p.addLine(to: position) }
                    }
                    p.closeSubpath()
                }
            }
            func draw(_ face: PaperFace, moving: Bool = false) {
                var points = face.points
                var lifts: [Double] = []
                var front = face.front
                if moving, let operation {
                    let theta = progress * .pi
                    points = face.points.map { p in
                        p - operation.line.normal * (operation.line.distance(p) * (1 - cos(theta)))
                    }
                    lifts = face.points.map { abs(operation.line.distance($0)) * sin(theta) }
                    if progress > 0.5 { front.toggle() }
                }
                let outline = path(points, lift: lifts)
                let base = front ? Color(red: 0.95, green: 0.91, blue: 0.81) : paperColor
                var shadowContext = context
                shadowContext.addFilter(.shadow(color: .black.opacity(moving ? 0.13 : 0.07), radius: moving ? 7 : 2, x: 0, y: moving ? 7 : 2))
                shadowContext.fill(outline, with: .color(base))
                context.fill(outline, with: .linearGradient(Gradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.06)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height)))
                context.stroke(outline, with: .color(.brown.opacity(0.16)), lineWidth: 0.65)
                var grain = context
                grain.clip(to: outline)
                for i in 0..<240 {
                    let x = Double((i * 139 + 11) % 503) / 503 * size.width
                    let y = Double((i * 227 + 41) % 509) / 509 * size.height
                    grain.stroke(Path { p in
                        p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + 2, y: y + 0.5))
                    }, with: .color(.white.opacity(0.12)), lineWidth: 0.5)
                }
            }
            if progress > 0, let operation {
                // Turning over is a half turn of the whole stack around the vertical center line.
                let parts = operation.flip ? (fixed: [], moving: paper.faces) : paper.parts(for: operation)
                for face in parts.fixed { draw(face) }
                let moving = progress > 0.5 ? Array(parts.moving.reversed()) : parts.moving
                for face in moving { draw(face, moving: true) }
            } else {
                for face in paper.faces { draw(face) }
            }
            if showGuide, let operation, !operation.flip {
                let line = operation.line
                let a = screen(line.normal * line.offset - line.tangent * 1.2)
                let b = screen(line.normal * line.offset + line.tangent * 1.2)
                context.stroke(Path { p in p.move(to: a); p.addLine(to: b) }, with: .color(WorkshopStyle.ink.opacity(0.55)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 6]))
                let mark = screen(line.normal * (line.offset + 0.23))
                context.draw(Text("↶").font(.system(size: 28, weight: .light)).foregroundStyle(WorkshopStyle.ink), at: mark)
            }
            if let face {
                for eye in face.eyes {
                    let p = screen(eye), r = scale * face.eyeSize
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(WorkshopStyle.ink))
                }
                context.fill(path(face.nose), with: .color(WorkshopStyle.ink))
                for whisker in face.whiskers {
                    context.stroke(Path { p in p.addLines(whisker.map { screen($0) }) }, with: .color(WorkshopStyle.ink.opacity(0.7)), lineWidth: 0.8)
                }
            }
        }
        .accessibilityLabel("Paper model")
        .accessibilityValue("Layers and faces: \(paper.faces.count)")
    }
}

struct ToolButton: View {
    let title: String
    let symbol: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(WorkshopStyle.ink)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
    }
}
