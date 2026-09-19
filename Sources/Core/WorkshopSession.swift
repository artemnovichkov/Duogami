import SwiftUI

struct SavedWorkshop: Codable, Identifiable {
    var id = UUID()
    var title: String
    var pattern: PaperPattern?
    var operations: [PaperOperation] = []
    var tint: PaperTint = .ochre
    var updated = Date()
    var version = 1
}

@Observable
final class WorkshopStore {
    var projects: [SavedWorkshop] = []
    var error: String?
    private var loadFailed = false
    private let url: URL

    init(url: URL? = nil) {
        self.url = url ?? URL.applicationSupportDirectory.appending(path: "Duogami/workshops.json")
        do {
            if FileManager.default.fileExists(atPath: self.url.path) {
                let decoded = try JSONDecoder().decode([SavedWorkshop].self, from: Data(contentsOf: self.url))
                guard decoded.allSatisfy({ $0.version == 1 && $0.operations.count <= 200
                    && $0.operations.allSatisfy { $0.line.angle.isFinite && $0.line.offset.isFinite } }) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                projects = decoded
            }
        } catch { loadFailed = true; self.error = "Couldn’t read saved works. The original file was left unchanged." }
    }

    func save(_ project: SavedWorkshop) {
        // A failed load must not overwrite the original file with an empty collection.
        guard !loadFailed else { return }
        var updated = project
        updated.updated = .now
        var next = projects.filter { $0.id != project.id }
        next.insert(updated, at: 0)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: url, options: .atomic)
            projects = next
            self.error = nil
        } catch { self.error = "Couldn’t save your work. Keep the workshop open and try again later." }
    }
}

@Observable
final class WorkshopSession {
    var project: SavedWorkshop
    var undone: [PaperOperation] = []
    var preview = 0.0
    var rotation = 0.0
    var translation = PaperPoint(x: 0, y: 0)
    var layers: FoldLayers = .all
    var reverseSide = false
    var creaseOnly = false
    var useHinge = false
    var hinge = HingeGesture()
    var hingeAvailable = false
    var confirmation = 0
    var paper: PaperState

    init(project: SavedWorkshop) {
        self.project = project
        paper = .replay(project.operations)
    }

    var step: PatternStep? {
        guard let pattern = project.pattern, project.operations.count < pattern.steps.count else { return nil }
        return pattern.steps[project.operations.count]
    }
    var isComplete: Bool { project.pattern != nil && step == nil }
    var canUndo: Bool { !project.operations.isEmpty }
    var operation: PaperOperation {
        if let step { return step.operation }
        let normal = PaperPoint(x: 1, y: 0).rotated(-rotation)
        let line = FoldLine(angle: atan2(normal.y, normal.x), offset: -translation.x)
        return .init(line: reverseSide ? line.reversed : line, layers: layers, unfold: creaseOnly)
    }
    var canFold: Bool { !isComplete && project.operations.count < 200 && paper.canApply(operation) }

    func align() {
        guard let step else { return }
        rotation = -step.operation.line.angle
        translation = .init(x: -step.operation.line.offset, y: 0)
        resetInput()
    }

    func resetInput() { preview = 0; hinge.reset() }

    @discardableResult
    func commit() -> Bool {
        guard canFold else { return false }
        let op = operation
        project.operations.append(op)
        paper = paper.applying(op)
        undone = []
        preview = 0
        confirmation += 1
        if project.pattern != nil { rotation = 0; translation = .init(x: 0, y: 0) }
        return true
    }

    func undo() {
        guard let last = project.operations.popLast() else { return }
        undone.append(last)
        paper = .replay(project.operations)
        resetInput()
        rotation = 0; translation = .init(x: 0, y: 0)
    }

    func redo() {
        guard let next = undone.popLast() else { return }
        project.operations.append(next)
        paper = paper.applying(next)
        resetInput()
    }

    func flip() {
        guard project.pattern == nil, project.operations.count < 200 else { return }
        let op = PaperOperation(line: .init(angle: 0, offset: 0), flip: true)
        project.operations.append(op)
        paper = paper.applying(op)
        undone = []
        resetInput()
    }

    func receive(angle: Double?, sceneActive: Bool, aligned: Bool) {
        hingeAvailable = angle != nil
        let didFold = hinge.update(angle: angle, enabled: useHinge && sceneActive && aligned && canFold)
        if didFold { _ = commit() }
        else if useHinge { preview = hinge.progress }
    }
}
