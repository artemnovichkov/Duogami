import Foundation

struct PatternStep {
    let title: String
    let instruction: String
    let operation: PaperOperation
}

/// Decorative drawing in final paper coordinates; on real paper it is added with a pencil.
struct PatternFace {
    var eyes: [PaperPoint]
    var eyeSize = 0.023
    var nose: [PaperPoint]
    var whiskers: [[PaperPoint]] = []
}

enum PaperPattern: String, Codable, CaseIterable, Identifiable {
    case puppy, kitten, fox
    var id: String { rawValue }

    var title: String {
        switch self {
        case .puppy: "Paper Friend"
        case .kitten: "Paper Kitten"
        case .fox: "Paper Fox"
        }
    }

    var subtitle: String {
        switch self {
        case .puppy: "Traditional puppy"
        case .kitten: "Traditional cat face"
        case .fox: "Traditional fox face"
        }
    }

    var animal: String {
        switch self {
        case .puppy: "Puppy"
        case .kitten: "Kitten"
        case .fox: "Fox"
        }
    }

    var source: URL {
        switch self {
        case .puppy: URL(string: "https://www.origami-instructions.com/origami-dog-face.html")!
        case .kitten: URL(string: "https://www.origami-instructions.com/origami-cat-face.html")!
        case .fox: URL(string: "https://www.origami-instructions.com/origami-fox-face.html")!
        }
    }

    var variation: String {
        switch self {
        case .puppy: "Ear proportions can vary."
        case .kitten: "Ear size and angle can vary."
        case .fox: "The fox can be as sharp or as soft as you like."
        }
    }

    var finishNote: String {
        switch self {
        case .puppy: "Your puppy is ready. Draw the eyes and nose on the paper."
        case .kitten: "Your kitten is ready. Draw the eyes, nose and whiskers."
        case .fox: "Your fox is ready. Give it sly eyes and a small nose."
        }
    }

    var steps: [PatternStep] {
        switch self {
        case .puppy:
            [
                .init(title: "Corner to corner", instruction: "Place the square colored side down. Bring the top corner to the bottom one to make a triangle.", operation: .init(line: .init(angle: -.pi / 2, offset: 0))),
                .init(title: "Mark the center", instruction: "Fold the triangle in half, matching the side corners, then unfold. This crease helps keep the ears symmetrical.", operation: .init(line: .init(angle: 0, offset: 0), unfold: true)),
                .init(title: "First ear", instruction: "Fold the left corner down along the dashed line. Fold both layers together. The angle of the ear gives the puppy its character.", operation: .init(line: .through(.init(x: -0.55, y: 0), .init(x: -0.75, y: 0.25), moving: .init(x: -1, y: 0)))),
                .init(title: "Second ear", instruction: "Fold the right corner down the same way. Try to make the ears match — or leave them a little different.", operation: .init(line: .through(.init(x: 0.55, y: 0), .init(x: 0.75, y: 0.25), moving: .init(x: 1, y: 0)))),
                .init(title: "Final touch", instruction: "Fold the bottom tip up along the dashed line, through both layers. On real paper, just draw the eyes and nose.", operation: .init(line: .init(angle: .pi / 2, offset: 0.70)))
            ]
        case .kitten:
            [
                .init(title: "Corner to corner", instruction: "Place the square colored side down. Bring the bottom corner up to the top one to make a triangle.", operation: .init(line: .init(angle: .pi / 2, offset: 0))),
                .init(title: "Mark the center", instruction: "Fold the triangle in half, matching the side corners, then unfold.", operation: .init(line: .init(angle: 0, offset: 0), unfold: true)),
                .init(title: "Flat forehead", instruction: "Fold the top corner down, stopping a little above the bottom edge. This will be the top of the head.", operation: .init(line: .init(angle: -.pi / 2, offset: 0.6))),
                .init(title: "First ear", instruction: "Fold the left corner up along the dashed line so its tip rises above the head.", operation: .init(line: .through(.init(x: -0.05, y: 0), .init(x: -0.65, y: -0.35), moving: .init(x: -1, y: 0)))),
                .init(title: "Second ear", instruction: "Fold the right corner up the same way. Tall ears look curious, low ones look sleepy.", operation: .init(line: .through(.init(x: 0.05, y: 0), .init(x: 0.65, y: -0.35), moving: .init(x: 1, y: 0)))),
                .init(title: "Turn over", instruction: "Turn the paper over. The smooth side is the face.", operation: .init(line: .init(angle: 0, offset: 0), flip: true))
            ]
        case .fox:
            [
                .init(title: "Corner to corner", instruction: "Place the square colored side down. Bring the bottom corner up to the top one to make a triangle.", operation: .init(line: .init(angle: .pi / 2, offset: 0))),
                .init(title: "Mark the center", instruction: "Fold the triangle in half, matching the side corners, then unfold.", operation: .init(line: .init(angle: 0, offset: 0), unfold: true)),
                .init(title: "Top to bottom", instruction: "Fold the top corner down until it touches the middle of the bottom edge.", operation: .init(line: .init(angle: -.pi / 2, offset: 0.5))),
                .init(title: "Right side up", instruction: "Fold the right half up so the bottom edge lies on the center crease.", operation: .init(line: .through(.init(x: 0, y: 0), .init(x: 0.5, y: -0.5), moving: .init(x: 1, y: 0)))),
                .init(title: "Left side up", instruction: "Fold the left half up the same way. The paper becomes a small square.", operation: .init(line: .through(.init(x: 0, y: 0), .init(x: -0.5, y: -0.5), moving: .init(x: -1, y: 0)))),
                .init(title: "Turn over", instruction: "Turn the paper over. The bottom point is the fox’s nose.", operation: .init(line: .init(angle: 0, offset: 0), flip: true))
            ]
        }
    }

    var face: PatternFace {
        switch self {
        case .puppy:
            .init(eyes: [.init(x: -0.24, y: 0.32), .init(x: 0.24, y: 0.32)],
                  nose: [.init(x: -0.085, y: 0.48), .init(x: 0.085, y: 0.48), .init(x: 0, y: 0.56)])
        case .kitten:
            .init(eyes: [.init(x: -0.17, y: -0.38), .init(x: 0.17, y: -0.38)],
                  nose: [.init(x: -0.045, y: -0.26), .init(x: 0.045, y: -0.26), .init(x: 0, y: -0.215)],
                  whiskers: [-1.0, 1].flatMap { side in
                      [-0.05, 0.03].map { tilt in
                          [PaperPoint(x: side * 0.08, y: -0.22), .init(x: side * 0.36, y: -0.22 + tilt)]
                      }
                  })
        case .fox:
            .init(eyes: [.init(x: -0.14, y: -0.36), .init(x: 0.14, y: -0.36)], eyeSize: 0.02,
                  nose: [.init(x: -0.05, y: -0.1), .init(x: 0.05, y: -0.1), .init(x: 0, y: -0.04)])
        }
    }

    var result: PaperState { .replay(steps.map(\.operation)) }
}

enum PaperTint: String, Codable, CaseIterable, Identifiable {
    case ochre, clay, sage, blue
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ochre: "Ochre"
        case .clay: "Terracotta"
        case .sage: "Sage"
        case .blue: "Blue"
        }
    }
}
