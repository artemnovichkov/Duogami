import SwiftUI

struct CollectionView: View {
    @Environment(WorkshopStore.self) private var store
    @State private var selected: SavedWorkshop?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max")
                        Text("A little paper. A little quiet.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(WorkshopStyle.secondary)

                    ForEach(Array(PaperPattern.allCases.enumerated()), id: \.element) { index, pattern in
                        lessonCard(pattern, number: index + 1)
                    }

                    Button { selected = SavedWorkshop(title: "Free Fold", pattern: nil, tint: .sage) } label: {
                        HStack(spacing: 18) {
                            Image(systemName: "square.on.square")
                                .font(.system(size: 25, weight: .ultraLight))
                                .frame(width: 58, height: 64)
                                .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Blank Sheet").font(.system(.title3, design: .serif))
                                Text("Your ideas. Your folds.").font(.caption).foregroundStyle(WorkshopStyle.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus").font(.title3.weight(.light))
                        }
                        .padding(20)
                        .foregroundStyle(WorkshopStyle.ink)
                        .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(WorkshopStyle.ink.opacity(0.08)))
                    }.buttonStyle(.plain)

                    if !store.projects.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("On Your Desk").font(.system(.title3, design: .serif))
                            ForEach(store.projects) { project in
                                Button { selected = project } label: {
                                    HStack(spacing: 14) {
                                        PaperCanvas(paper: .replay(project.operations), tint: project.tint, fitToContent: true)
                                            .frame(width: 72, height: 72)
                                            .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(project.title).font(.subheadline.weight(.medium))
                                            Text("Actions: \(project.operations.count) · \(project.updated.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption).foregroundStyle(WorkshopStyle.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right").font(.caption)
                                    }.foregroundStyle(WorkshopStyle.ink)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if let error = store.error {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "hand.draw")
                        Text("Made by the motion of your hands")
                    }
                    .font(.caption).foregroundStyle(WorkshopStyle.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .padding(.horizontal, 26).padding(.vertical, 32)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
            .background(WorkbenchBackground().ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $selected) { project in
                WorkshopView(project: project)
            }
        }
        .tint(WorkshopStyle.accent)
    }

    private func lessonCard(_ pattern: PaperPattern, number: Int) -> some View {
        Button { selected = SavedWorkshop(title: pattern.title, pattern: pattern) } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(pattern.subtitle.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
                    Spacer()
                    Text(String(format: "%02d", number)).font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(WorkshopStyle.secondary)
                .padding(24)
                PaperCanvas(paper: pattern.result, tint: .ochre, face: pattern.face, fitToContent: true)
                    .frame(height: 245)
                    .rotationEffect(.degrees(number.isMultiple(of: 2) ? 6 : -8))
                    .padding(.top, -40)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pattern.title).font(.system(.title2, design: .serif))
                        Text("\(pattern.animal) · \(pattern.steps.count) steps · Beginner")
                            .font(.caption).foregroundStyle(WorkshopStyle.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.title3)
                }.padding(24)
            }
            .foregroundStyle(WorkshopStyle.ink)
            .background(Color(red: 0.91, green: 0.89, blue: 0.83), in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.7), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("DUOGAMI").font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(5)
                    .foregroundStyle(WorkshopStyle.secondary)
                Text("A workshop\nof small wonders.")
                    .font(.system(size: 39, weight: .regular, design: .serif)).tracking(-1.5)
                    .foregroundStyle(WorkshopStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 26, weight: .ultraLight))
                .foregroundStyle(WorkshopStyle.accent)
                .padding(15)
                .background(.white.opacity(0.5), in: Circle())
        }
    }
}
