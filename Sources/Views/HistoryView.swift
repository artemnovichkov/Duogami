import SwiftUI

/// A saved free-form session is also a replayable recipe. Scrubbing never edits it.
struct HistoryView: View {
    let project: SavedWorkshop
    @Environment(\.dismiss) private var dismiss
    @State private var position = 0.0

    private var index: Int { min(Int(position), project.operations.count) }
    private var paper: PaperState { .replay(Array(project.operations.prefix(index))) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                PaperCanvas(paper: paper, tint: project.tint, fitToContent: true)
                    .frame(maxHeight: .infinity)
                VStack(spacing: 8) {
                    Text(index == 0 ? "Blank sheet" : "Action \(index) of \(project.operations.count)")
                        .font(.system(.title2, design: .serif))
                    Text(description).font(.subheadline).foregroundStyle(WorkshopStyle.secondary)
                        .multilineTextAlignment(.center)
                }
                if !project.operations.isEmpty {
                    Slider(value: $position, in: 0...Double(project.operations.count), step: 1)
                        .accessibilityLabel("Step of your own diagram")
                    HStack {
                        Button("Back", systemImage: "arrow.left") { position -= 1 }
                            .disabled(index == 0)
                        Spacer()
                        Button("Next", systemImage: "arrow.right") { position += 1 }
                            .disabled(index == project.operations.count)
                    }.buttonStyle(.bordered).controlSize(.large)
                }
                Text("All actions are saved with your work. You can return to this diagram at any time.")
                    .font(.caption).foregroundStyle(WorkshopStyle.secondary).multilineTextAlignment(.center)
            }
            .padding(28)
            .background(WorkbenchBackground().ignoresSafeArea())
            .navigationTitle("My Diagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var description: String {
        guard index > 0 else { return "Every work begins with a single square." }
        let op = project.operations[index - 1]
        if op.flip { return "Turn the paper over" }
        let action = op.unfold ? "Crease and unfold" : "Fold the paper"
        return action + (op.layers == .all ? " · all layers" : " · top face")
    }
}
