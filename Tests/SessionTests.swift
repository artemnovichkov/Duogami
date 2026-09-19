import Foundation

@main
@MainActor
struct SessionTests {
    static func main() throws {
        var count = 0
        func check(_ value: Bool, _ message: String) { precondition(value, message); count += 1 }
        let project = SavedWorkshop(title: "Test", pattern: .puppy)
        let session = WorkshopSession(project: project)
        check(session.step != nil && session.canFold, "Tutorial starts ready")
        check(session.commit(), "First fold commits")
        let folded = session.paper
        session.undo()
        check(session.paper == .square && !session.canUndo, "Undo restores blank square")
        session.redo()
        check(session.paper == folded && session.undone.isEmpty, "Redo restores fold")
        while !session.isComplete { check(session.commit(), "Tutorial step commits") }
        check(session.project.operations.count == 5 && !session.canFold, "Finished tutorial cannot fold again")
        let finished = session.paper
        session.undo(); session.redo()
        check(session.paper == finished && session.isComplete, "Finished state survives undo/redo")
        session.undo(); _ = session.commit()
        check(session.undone.isEmpty, "Branch discards redo history")
        let kitten = WorkshopSession(project: .init(title: "Kitten", pattern: .kitten))
        while !kitten.isComplete { check(kitten.commit(), "Lesson with a turn over commits") }
        check(kitten.paper == PaperPattern.kitten.result, "Lesson session matches pattern result")
        let free = WorkshopSession(project: .init(title: "Free", pattern: nil))
        free.translation = .init(x: 0.2, y: 0)
        free.rotation = .pi / 4
        let onScreenHinge = PaperPoint(x: -0.2, y: 0).rotated(-free.rotation)
        check(abs(free.operation.line.distance(onScreenHinge)) < 1e-8, "Screen crease maps back to paper coordinates")
        free.flip(); free.undo()
        check(free.paper == .square, "Flip is undoable")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "workshops.json")
        let store = WorkshopStore(url: url)
        store.save(session.project)
        check(store.error == nil && store.projects.count == 1, "Save creates directory and file")
        store.save(session.project)
        check(store.projects.count == 1, "Save updates existing project")
        let reopened = WorkshopStore(url: url)
        check(reopened.projects.count == 1, "Reload finds saved project")
        let restored = WorkshopSession(project: reopened.projects[0])
        check(restored.paper == session.paper && restored.isComplete, "Progress restored exactly")
        let damaged = Data("broken data".utf8)
        try damaged.write(to: url)
        let corrupt = WorkshopStore(url: url)
        check(corrupt.error != nil, "Corrupt data is reported")
        corrupt.save(project)
        let preserved = try Data(contentsOf: url)
        check(preserved == damaged, "Corrupt source is never overwritten")
        print("Passed \(count) session and persistence checks.")
    }
}
