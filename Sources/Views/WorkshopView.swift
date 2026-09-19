import SwiftUI

struct WorkshopView: View {
    @Environment(WorkshopStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: WorkshopSession
    @State private var showHelp = false
    @State private var showSteps = false
    @State private var dragStart: PaperPoint?
    @State private var rotationStart: Double?
    @State private var showFinish = false
    @State private var committing = false
    @State private var showHistory = false
    @State private var hasDivision = false

    init(project: SavedWorkshop) {
        _session = State(initialValue: WorkshopSession(project: project))
    }

    private var aligned: Bool {
        guard session.project.pattern != nil else { return true }
        let normal = session.operation.line.normal.rotated(session.rotation)
        return abs(normal.y) < 0.03 && abs(session.operation.line.offset + session.translation.x) < 0.03
    }

    var body: some View {
        @Bindable var session = session
        VStack(spacing: 0) {
            header.padding(.horizontal, 22).padding(.top, 12)
            GeometryReader { proxy in
                // Read every layout pass: inactive regions locate the hinge when flat.
                let division = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first?.frame
                let horizontal = (division?.width ?? 0) > (division?.height ?? 1)
                let origin = division.map { rect in
                    horizontal ? CGPoint(x: proxy.size.width / 2, y: rect.midY)
                        : CGPoint(x: rect.midX, y: proxy.size.height / 2)
                }
                ZStack {
                    if !session.isComplete {
                        hingeGuide(horizontal: horizontal, origin: origin, size: proxy.size)
                    }
                    PaperCanvas(paper: session.paper, tint: session.project.tint,
                                operation: session.isComplete ? nil : session.operation,
                                progress: session.preview, rotation: session.rotation,
                                translation: session.translation, showGuide: !session.isComplete,
                                face: session.isComplete ? session.project.pattern?.face : nil, origin: origin, horizontalHinge: horizontal, fitToContent: session.isComplete)
                        .contentShape(Rectangle())
                        .gesture(DragGesture().onChanged { value in
                            guard session.project.pattern == nil, session.preview == 0 else { return }
                            if dragStart == nil { dragStart = session.translation; session.resetInput() }
                            let scale = min(proxy.size.width, proxy.size.height) * 0.43
                            let raw = PaperPoint(x: value.translation.width / scale, y: value.translation.height / scale)
                            let movement = horizontal ? raw.rotated(-.pi / 2) : raw
                            var offset = (dragStart ?? .init(x: 0, y: 0)) + movement
                            // Snap to the center and existing vertices without hiding the chosen crease.
                            let candidates = [0.0] + session.paper.faces.flatMap(\.points).map { -$0.rotated(session.rotation).x }
                            if let nearest = candidates.min(by: { abs($0 - offset.x) < abs($1 - offset.x) }), abs(nearest - offset.x) < 0.035 {
                                offset.x = nearest
                            }
                            offset.x = min(max(offset.x, -1.4), 1.4)
                            offset.y = min(max(offset.y, -0.7), 0.7)
                            session.translation = offset
                        }.onEnded { _ in dragStart = nil })
                        .simultaneousGesture(RotateGesture().onChanged { value in
                            guard session.project.pattern == nil, session.preview == 0 else { return }
                            if rotationStart == nil { rotationStart = session.rotation; session.resetInput() }
                            session.rotation = (rotationStart ?? 0) + value.rotation.radians
                        }.onEnded { _ in
                            session.rotation = (session.rotation / (.pi / 12)).rounded() * (.pi / 12)
                            rotationStart = nil
                        })
                    VStack {
                        HStack {
                            Text(session.isComplete ? "MADE BY YOU" : "\(session.project.pattern == nil ? "FREE FOLD" : "SHEET 01")")
                                .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2)
                            Spacer()
                            if !session.isComplete {
                                Text(session.project.pattern == nil ? "Actions: \(session.project.operations.count)" : "\(session.project.operations.count + 1) / \(session.project.pattern!.steps.count)")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                        Spacer()
                        if session.project.pattern == nil && session.preview == 0 {
                            Text("Move and rotate the paper")
                                .font(.caption).padding(.bottom, 8)
                        }
                    }
                    .foregroundStyle(WorkshopStyle.secondary)
                    .padding(24).allowsHitTesting(false)
                }
                .onChange(of: division, initial: true) { _, value in
                    hasDivision = value != nil
                    session.resetInput()
                }
            }
            .frame(minHeight: 200)
            controls
        }
        .background(WorkbenchBackground().ignoresSafeArea())
        .foregroundStyle(WorkshopStyle.ink)
        .tint(WorkshopStyle.accent)
        .toolbarVerticalBehavior(.disabled)
        .sensoryFeedback(.success, trigger: session.confirmation)
        .onHingeChange { _, context in
            session.receive(angle: context.hinge?.angle.degrees, sceneActive: scenePhase == .active && !showHelp && !showSteps && !showFinish && !showHistory && !committing,
                            aligned: aligned && hasDivision)
        }
        .onChange(of: session.project.operations) { _, _ in store.save(session.project) }
        .onChange(of: session.project.tint) { _, _ in store.save(session.project) }
        .onChange(of: session.useHinge) { _, _ in session.resetInput() }
        .onChange(of: scenePhase) { _, phase in
            committing = false
            session.resetInput()
            if phase != .active { store.save(session.project) }
        }
        .onDisappear { committing = false; store.save(session.project) }
        .sheet(isPresented: $showHelp) { help }
        .sheet(isPresented: $showSteps) { steps }
        .sheet(isPresented: $showFinish) { finish }
        .sheet(isPresented: $showHistory) { HistoryView(project: session.project) }
    }

    private var header: some View {
        HStack {
            Button { store.save(session.project); dismiss() } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }.accessibilityLabel("Back to workshop")
            Spacer()
            VStack(spacing: 4) {
                Text("DUOGAMI").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(3)
                    .foregroundStyle(WorkshopStyle.secondary)
                Text(session.project.title).font(.system(.headline, design: .serif))
            }
            Spacer()
            Button { showHelp = true; session.resetInput() } label: {
                Image(systemName: "questionmark").frame(width: 44, height: 44)
            }.accessibilityLabel("How to fold")
        }.buttonStyle(.plain)
    }

    private func hingeGuide(horizontal: Bool, origin: CGPoint?, size: CGSize) -> some View {
        Path { path in
            if horizontal {
                let y = origin?.y ?? size.height / 2
                path.move(to: CGPoint(x: 28, y: y)); path.addLine(to: CGPoint(x: size.width - 28, y: y))
            } else {
                let x = origin?.x ?? size.width / 2
                path.move(to: CGPoint(x: x, y: 42)); path.addLine(to: CGPoint(x: x, y: size.height - 30))
            }
        }
        .stroke(WorkshopStyle.accent.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [2, 7]))
        .accessibilityHidden(true)
    }

    private var controls: some View {
        @Bindable var session = session
        return VStack(spacing: 15) {
            HStack(spacing: 12) {
                ToolButton(title: "Undo", symbol: "arrow.uturn.backward") { animate { session.undo() } }
                    .labelStyle(.iconOnly).disabled(!session.canUndo).opacity(session.canUndo ? 1 : 0.35)
                ToolButton(title: "Redo", symbol: "arrow.uturn.forward") { animate { session.redo() } }
                    .labelStyle(.iconOnly).disabled(session.undone.isEmpty).opacity(session.undone.isEmpty ? 0.35 : 1)
                Spacer()
                ForEach(PaperTint.allCases) { tint in
                    Button { session.project.tint = tint } label: {
                        Circle().fill(tint.color).frame(width: 21, height: 21)
                            .padding(5)
                            .overlay(Circle().strokeBorder(session.project.tint == tint ? WorkshopStyle.ink.opacity(0.5) : .clear, lineWidth: 1))
                            .frame(minWidth: 34, minHeight: 44)
                    }.accessibilityLabel("Paper: \(tint.title)")
                        .accessibilityAddTraits(session.project.tint == tint ? .isSelected : [])
                }
            }
            if session.isComplete {
                VStack(spacing: 8) {
                    Text("Every sheet has its own character.").font(.system(.title3, design: .serif))
                    Text(session.project.pattern?.finishNote ?? "")
                        .font(.caption).foregroundStyle(WorkshopStyle.secondary)
                    Button("Keep on Desk") { showFinish = true }
                        .buttonStyle(.borderedProminent).foregroundStyle(.white).controlSize(.large).padding(.top, 8)
                }.padding(.vertical, 12)
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(session.step?.title ?? "Follow your idea")
                            .font(.system(.title2, design: .serif))
                        Text(session.step?.instruction ?? "The hinge line becomes the new fold. Pick a side, then fold the paper.")
                            .font(.subheadline).foregroundStyle(WorkshopStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if session.project.pattern != nil {
                        Button { showSteps = true; session.resetInput() } label: {
                            Image(systemName: "list.bullet").frame(width: 44, height: 44)
                        }.accessibilityLabel("All diagram steps")
                    }
                }
                if session.project.pattern == nil { freeTools }
                HStack {
                    Toggle(isOn: $session.useHinge) {
                        Label("Fold with iPhone", systemImage: "rectangle.split.2x1")
                            .font(.subheadline)
                    }
                    .disabled(!session.hingeAvailable)
                }
                if session.useHinge {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                        Text(hingeHint).font(.caption)
                        Spacer()
                        if !aligned, session.project.pattern != nil {
                            Button("Align") { animate { session.align() } }.font(.caption.weight(.semibold))
                        }
                    }.foregroundStyle(WorkshopStyle.accent)
                    ProgressView(value: session.preview).accessibilityLabel("Fold progress")
                } else {
                    HStack(spacing: 14) {
                        Image(systemName: "hand.draw").foregroundStyle(WorkshopStyle.secondary)
                        Slider(value: $session.preview, in: 0...1)
                            .accessibilityLabel("Fold preview")
                            .disabled(!session.canFold)
                        Button(session.operation.flip ? "Turn Over" : session.operation.unfold ? "Crease" : "Fold") {
                            commitWithAnimation()
                        }
                        .buttonStyle(.borderedProminent).foregroundStyle(.white).controlSize(.large)
                        .disabled(!session.canFold)
                    }
                }
                if !session.canFold {
                    Text(session.project.operations.count >= 200 ? "This work has reached its limit: 200 actions." : "Move the sheet: the line must cross the paper.")
                        .font(.caption).foregroundStyle(WorkshopStyle.secondary)
                }
                if let error = store.error { Text(error).font(.caption).foregroundStyle(.red) }
            }
        }
        .disabled(committing)
        .padding(22)
        .background(.white.opacity(0.42), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
    }

    private var freeTools: some View {
        @Bindable var session = session
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                ToolButton(title: "Rotate", symbol: "rotate.right") {
                    animate { session.rotation += .pi / 2; session.resetInput() }
                }.labelStyle(.iconOnly)
                ToolButton(title: "Flip", symbol: "arrow.triangle.2.circlepath") {
                    animate { session.flip() }
                }.labelStyle(.iconOnly)
                ToolButton(title: "Switch Side", symbol: "arrow.left.arrow.right") {
                    session.reverseSide.toggle(); session.resetInput()
                }.labelStyle(.iconOnly)
                Picker("Layers", selection: $session.layers) {
                    Text("All Layers").tag(FoldLayers.all)
                    Text("Top Face").tag(FoldLayers.top)
                }.pickerStyle(.menu).font(.caption)
                Button { showHistory = true; session.resetInput() } label: {
                    Image(systemName: "list.bullet.rectangle").frame(width: 44, height: 44)
                }.accessibilityLabel("My Diagram")
                Spacer(minLength: 0)
            }
            Toggle("Crease and unfold", isOn: $session.creaseOnly).font(.caption)
                .onChange(of: session.creaseOnly) { _, _ in session.resetInput() }
                .onChange(of: session.layers) { _, _ in session.resetInput() }
        }
    }

    private var hingeHint: String {
        if !hasDivision { return "Open the inner display or use the slider." }
        if !aligned { return "Align the dashed line with the phone’s fold." }
        switch session.hinge.phase {
        case .needsOpen: return "Open iPhone to begin." 
        case .ready: return "Gently fold iPhone — the crease will appear."
        case .folding: return "Keep folding. No need to close it fully."
        case .needsReopen: return "Done. Open iPhone for the next step."
        }
    }

    private func commitWithAnimation() {
        guard session.canFold, !committing else { return }
        if reduceMotion { _ = session.commit(); session.hinge.reset(); return }
        committing = true
        withAnimation(.easeInOut(duration: 0.55)) { session.preview = 1 } completion: {
            guard committing else { return }
            if session.operation.unfold {
                withAnimation(.easeInOut(duration: 0.45)) { session.preview = 0 } completion: {
                    guard committing else { return }
                    _ = session.commit(); session.hinge.reset(); committing = false
                }
            } else {
                _ = session.commit(); session.hinge.reset(); committing = false
            }
        }
    }

    private func animate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35), action)
    }

    private var help: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("It all begins\nwith a single fold.")
                        .font(.system(.largeTitle, design: .serif))
                    Label("Align the line", systemImage: "move.3d")
                        .font(.headline)
                    Text("In Free Fold, move the sheet with one finger and rotate it with two. In a lesson, the “Align” button places the next fold on the hinge.")
                    Label("Fold and open", systemImage: "rectangle.split.2x1")
                        .font(.headline)
                    Text("Turn on “Fold with iPhone”, open the device and gently close it. After confirmation, open it again: the paper stays folded. The slider and button do the same without the hinge.")
                    Label("Work with real paper", systemImage: "square.on.square")
                        .font(.headline)
                    Text("Each lesson needs a square, for example 15 × 15 cm (6 × 6 in). Repeat each action on your sheet and tap “Fold” to see the next step. The dashed line shows where to fold, the arrow shows the moving side.")
                    Text("Free Fold currently supports flat straight folds. The paper isn’t checked for collisions or stretching; complex 3D models and folds of individual connected flaps aren’t supported yet.")
                        .font(.footnote).foregroundStyle(WorkshopStyle.secondary)
                }.padding(28)
            }
            .background(WorkbenchBackground())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Got It") { showHelp = false } } }
        }
    }

    private var steps: some View {
        NavigationStack {
            List {
                if let pattern = session.project.pattern {
                    Section("Square of paper · about 15 × 15 cm") {
                        ForEach(Array(pattern.steps.enumerated()), id: \.offset) { index, step in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(index + 1). \(step.title)").font(.headline)
                                Text(step.instruction).font(.subheadline).foregroundStyle(.secondary)
                            }.padding(.vertical, 6)
                        }
                    }
                    Section("About the Diagram") {
                        Text("Traditional model. Duogami’s geometry, illustrations and wording were created for the app. \(pattern.variation)")
                        Link("View source instructions", destination: pattern.source)
                    }
                }
            }
            .navigationTitle(session.project.pattern?.title ?? "")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSteps = false } } }
        }
    }

    private var finish: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PaperCanvas(paper: session.paper, tint: session.project.tint, face: session.project.pattern?.face, fitToContent: true).frame(height: 280)
                Text("Your \(session.project.pattern?.title ?? session.project.title)").font(.system(.largeTitle, design: .serif))
                Text("\(stepCount) steps. One square.\nAnd something made with your own hands.")
                    .multilineTextAlignment(.center).foregroundStyle(WorkshopStyle.secondary)
                ShareLink(item: exportImage, preview: SharePreview("Duogami — \(session.project.title)", image: exportImage)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }.buttonStyle(.borderedProminent).foregroundStyle(.white).controlSize(.large)
                Button("Back to Workshop") { store.save(session.project); showFinish = false; dismiss() }
                Spacer()
            }.padding(24).background(WorkbenchBackground())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showFinish = false } } }
        }
    }

    private var stepCount: String {
        // UI is English-only, so spell out in English regardless of the device locale.
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: "en")
        let count = session.project.pattern?.steps.count ?? session.project.operations.count
        return (formatter.string(from: count as NSNumber) ?? "\(count)").capitalized
    }

    private var exportImage: Image {
        let renderer = ImageRenderer(content:
            VStack(spacing: 0) {
                PaperCanvas(paper: session.paper, tint: session.project.tint, face: session.project.pattern?.face, fitToContent: true).frame(width: 800, height: 700)
                Text("DUOGAMI").font(.system(size: 20, design: .monospaced)).tracking(6).padding(.bottom, 50)
            }.foregroundStyle(WorkshopStyle.ink).background(WorkshopStyle.background)
        )
        if let image = renderer.cgImage { return Image(decorative: image, scale: 1) }
        return Image(systemName: "square.on.square")
    }
}
