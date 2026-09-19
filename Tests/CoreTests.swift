import Foundation

@main
struct CoreTests {
    static func main() throws {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-7 }
        func covers(_ face: PaperFace, _ p: PaperPoint) -> Bool {
            let sides = face.points.indices.map { i in
                let a = face.points[i], b = face.points[(i + 1) % face.points.count]
                return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
            }
            return sides.allSatisfy { $0 >= 0 } || sides.allSatisfy { $0 <= 0 }
        }
        let square = PaperState.square
        check(close(square.faces[0].area, 2), "Square area")
        let center = FoldLine(angle: 0, offset: 0)
        let point = PaperPoint(x: 0.8, y: -0.3)
        check(close(center.reflected(point).x, -0.8), "Reflection")
        let restored = center.reflected(center.reflected(point))
        check(close(restored.x, point.x) && close(restored.y, point.y), "Reflection involution")
        for index in 0..<64 {
            let line = FoldLine(angle: Double(index) * .pi / 32, offset: Double(index % 7 - 3) / 5)
            let op = PaperOperation(line: line)
            let paper = square.applying(op)
            check(paper.faces.allSatisfy { $0.area > 0 }, "No degenerate face")
            check(close(paper.faces.reduce(0) { $0 + $1.area }, 2), "Fold conserves material area")
            check(paper.faces.flatMap(\.points).allSatisfy { line.distance($0) < 1e-7 }, "Folded geometry stays in fixed half-plane")
        }
        let crease = PaperOperation(line: center, unfold: true)
        let creased = square.applying(crease)
        check(creased.faces.count == 2, "Crease retained as split")
        check(creased.canApply(.init(line: center)), "Can refold an existing crease")
        check(close(creased.applying(.init(line: center)).faces.reduce(0) { $0 + $1.area }, 2), "Refold conserves paper")
        check(!square.canApply(.init(line: .init(angle: 0, offset: 2))), "Outside crease rejected")
        check(!square.canApply(.init(line: .init(angle: 0, offset: 1))), "Tangent crease rejected")
        let first = square.applying(.init(line: center))
        let top = PaperOperation(line: .init(angle: .pi / 2, offset: 0), layers: .top)
        let topResult = first.applying(top)
        check(topResult.faces[0] == first.faces[0], "Top-only fold leaves bottom layer unchanged")
        let flip = PaperOperation(line: center, flip: true)
        check(first.applying(flip).applying(flip) == first, "Flip twice restores paper and stack")
        for pattern in PaperPattern.allCases {
            var lesson = square
            for step in pattern.steps {
                check(lesson.canApply(step.operation), "Every tutorial step is executable: \(pattern) \(step.title)")
                let next = lesson.applying(step.operation)
                check(next != lesson, "Every tutorial step changes the paper: \(pattern) \(step.title)")
                lesson = next
                check(close(lesson.faces.reduce(0) { $0 + $1.area }, 2), "Tutorial conserves paper")
            }
            let marks = pattern.face.eyes + pattern.face.nose
            check(marks.allSatisfy { mark in lesson.faces.contains { covers($0, mark) } }, "Face is drawn on the paper: \(pattern)")
        }
        var state = square
        for step in PaperPattern.puppy.steps { state = state.applying(step.operation) }
        let ops = PaperPattern.puppy.steps.map(\.operation)
        let encoded = try JSONEncoder().encode(ops)
        let decoded = try JSONDecoder().decode([PaperOperation].self, from: encoded)
        check(decoded == ops, "Operations round-trip")
        check(PaperState.replay(decoded) == state, "Replay reproduces saved model")
        check(PaperState.replay(Array(ops.dropLast())).applying(ops.last!) == state, "Undo and redo reproduce geometry")
        var hinge = HingeGesture()
        check(!hinge.update(angle: 60, enabled: true), "Initial closed state cannot commit")
        check(!hinge.update(angle: 180, enabled: true), "Opening arms input")
        check(!hinge.update(angle: 100, enabled: true), "Partial gesture previews")
        check(hinge.progress > 0 && hinge.progress < 1, "Preview is normalized")
        check(hinge.update(angle: 79, enabled: true), "Crossing threshold commits")
        for angle in [81.0, 79, 60, 90, 40] {
            check(!hinge.update(angle: angle, enabled: true), "Jitter cannot double commit")
        }
        check(!hinge.update(angle: 160, enabled: true), "Reopen rearms without commit")
        check(hinge.update(angle: 70, enabled: true), "Next cycle works")
        check(!hinge.update(angle: nil, enabled: true), "Missing hinge resets")
        check(!hinge.update(angle: 60, enabled: true), "Missing-data recovery cannot commit")
        _ = hinge.update(angle: 180, enabled: true)
        check(!hinge.update(angle: 60, enabled: false), "Background or sheet disables input")
        check(!hinge.update(angle: 60, enabled: true), "Resume requires reopen")
        check(!hinge.update(angle: .nan, enabled: true), "Invalid sample rejected")
        print("Passed \(checks) geometry, replay and hinge checks.")
    }
}
