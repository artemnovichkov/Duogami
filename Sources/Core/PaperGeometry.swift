import Foundation

/// Paper coordinates are independent of screen size; the initial square is a diamond.
nonisolated struct PaperPoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double

    static func + (a: Self, b: Self) -> Self { .init(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: Self, b: Self) -> Self { .init(x: a.x - b.x, y: a.y - b.y) }
    static func * (p: Self, s: Double) -> Self { .init(x: p.x * s, y: p.y * s) }
    func dot(_ p: Self) -> Double { x * p.x + y * p.y }
    func rotated(_ angle: Double) -> Self {
        .init(x: x * cos(angle) - y * sin(angle), y: x * sin(angle) + y * cos(angle))
    }
}

/// A unit normal defines the moving half-plane: dot(point, normal) > offset.
nonisolated struct FoldLine: Codable, Equatable, Sendable {
    var angle: Double
    var offset: Double
    var normal: PaperPoint { .init(x: cos(angle), y: sin(angle)) }
    var tangent: PaperPoint { .init(x: -sin(angle), y: cos(angle)) }
    func distance(_ point: PaperPoint) -> Double { point.dot(normal) - offset }
    func reflected(_ point: PaperPoint) -> PaperPoint { point - normal * (2 * distance(point)) }
    var reversed: Self { .init(angle: angle + .pi, offset: -offset) }

    static func through(_ a: PaperPoint, _ b: PaperPoint, moving point: PaperPoint) -> Self {
        let delta = b - a
        let angle = atan2(delta.x, -delta.y)
        var line = Self(angle: angle, offset: 0)
        line.offset = a.dot(line.normal)
        return line.distance(point) >= 0 ? line : line.reversed
    }
}

nonisolated struct PaperFace: Codable, Equatable, Sendable {
    var points: [PaperPoint]
    var front = true
    var area: Double {
        guard points.count >= 3 else { return 0 }
        return abs(points.indices.reduce(0) { value, i in
            let a = points[i], b = points[(i + 1) % points.count]
            return value + a.x * b.y - b.x * a.y
        }) / 2
    }

    func clipped(by line: FoldLine, positive: Bool) -> Self? {
        guard points.count >= 3 else { return nil }
        var result: [PaperPoint] = []
        for i in points.indices {
            let a = points[i], b = points[(i + 1) % points.count]
            let da = line.distance(a) * (positive ? 1 : -1)
            let db = line.distance(b) * (positive ? 1 : -1)
            if da >= -1e-9 { result.append(a) }
            if (da > 1e-9 && db < -1e-9) || (da < -1e-9 && db > 1e-9) {
                result.append(a + (b - a) * (da / (da - db)))
            }
        }
        let face = Self(points: result, front: front)
        return face.area > 1e-8 ? face : nil
    }
}

nonisolated enum FoldLayers: String, Codable, CaseIterable, Sendable {
    case all, top
}

nonisolated struct PaperOperation: Codable, Equatable, Sendable {
    var line: FoldLine
    var layers: FoldLayers = .all
    var unfold = false
    var flip = false
}

/// Ordered convex faces, back to front. This is a flat-fold geometry model, not a
/// collision/strain solver: advanced pocket, reverse and squash folds aren't supported.
nonisolated struct PaperState: Equatable, Sendable {
    var faces: [PaperFace]
    static let square = Self(faces: [.init(points: [
        .init(x: 0, y: -1), .init(x: 1, y: 0),
        .init(x: 0, y: 1), .init(x: -1, y: 0)
    ])])

    func parts(for operation: PaperOperation) -> (fixed: [PaperFace], moving: [PaperFace]) {
        var fixed: [PaperFace] = [], moving: [PaperFace] = []
        // Top means the topmost face on the moving side, not a connected physical flap.
        let top = faces.lastIndex { face in
            face.points.contains { operation.line.distance($0) > 1e-8 }
        }
        for (index, face) in faces.enumerated() {
            if operation.layers == .top && index != top {
                fixed.append(face)
                continue
            }
            if let piece = face.clipped(by: operation.line, positive: false) { fixed.append(piece) }
            if let piece = face.clipped(by: operation.line, positive: true) { moving.append(piece) }
        }
        return (fixed, moving)
    }

    func canApply(_ operation: PaperOperation) -> Bool {
        if operation.flip { return true }
        let parts = parts(for: operation)
        return !parts.moving.isEmpty && !parts.fixed.isEmpty
            && faces.flatMap(\.points).contains { operation.line.distance($0) > 1e-8 }
            && faces.flatMap(\.points).contains { operation.line.distance($0) < -1e-8 }
            && parts.fixed.count + parts.moving.count <= 512
    }

    func applying(_ operation: PaperOperation) -> Self {
        if operation.flip {
            return Self(faces: faces.reversed().map { face in
                .init(points: face.points.map { .init(x: -$0.x, y: $0.y) }, front: !face.front)
            })
        }
        guard canApply(operation) else { return self }
        if operation.unfold {
            // Split in place to retain the crease without changing the stack order.
            return Self(faces: faces.enumerated().flatMap { index, face -> [PaperFace] in
                if operation.layers == .top,
                   index != faces.lastIndex(where: { $0.points.contains { operation.line.distance($0) > 1e-8 } }) {
                    return [face]
                }
                return [face.clipped(by: operation.line, positive: false), face.clipped(by: operation.line, positive: true)].compactMap { $0 }
            })
        }
        let parts = parts(for: operation)
        let folded = parts.moving.reversed().map { face in
            PaperFace(points: face.points.map(operation.line.reflected), front: !face.front)
        }
        return Self(faces: parts.fixed + folded)
    }

    static func replay(_ operations: [PaperOperation]) -> Self {
        operations.reduce(.square) { $0.applying($1) }
    }
}

/// One confirmation per close/reopen cycle. Initial values and app resume cannot fold paper.
nonisolated struct HingeGesture {
    enum Phase { case needsOpen, ready, folding, needsReopen }
    var phase: Phase = .needsOpen
    var progress = 0.0

    mutating func reset() { phase = .needsOpen; progress = 0 }

    mutating func update(angle: Double?, enabled: Bool) -> Bool {
        guard enabled, let angle, angle.isFinite else { reset(); return false }
        switch phase {
        case .needsOpen, .needsReopen:
            if angle >= 155 { phase = .ready; progress = 0 }
        case .ready, .folding:
            progress = min(max((155 - angle) / 75, 0), 1)
            phase = angle < 145 ? .folding : .ready
            if angle <= 80 {
                phase = .needsReopen
                progress = 0
                return true
            }
        }
        return false
    }
}
