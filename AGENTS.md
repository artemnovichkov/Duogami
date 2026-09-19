# Duogami

Independent SwiftUI application for iPhone Duo, iOS 27.1, Swift 6.

- Build: `xcodebuild -project Duogami.xcodeproj -scheme Duogami -destination 'platform=iOS Simulator,name=iPhone Duo' build`.
- Tests: `bash Tests/run.sh` (geometry, hinge recognizer, session and persistence).
- JSON Xcode project: add source entries explicitly in `Duogami.xcodeproj/project.xcproj`.
- Keep geometry Foundation-only and nonisolated. Default app isolation is MainActor.
- Both guided and free modes must execute the same PaperOperation model.
- Use hinge for input; reserved regions for locating the physical division. Read regions every layout pass.
- Never infer a fold from the initial hinge sample; require opening before arming and reopening after confirmation.
- UI is English, minimal, warm and tactile. Keep technical implementation details out of primary UI.
- Do not claim physical validity of arbitrary free folds: no collision or connectivity solver yet.
- Traditional lesson illustrations and wording are original; preserve the source attribution in README and the lesson sheet.
- Simulator screenshots: `xcrun simctl io booted screenshot path.png`, outer display adds `--display=1`.
- Ask the user to change simulator fold state manually. Do not automate that state.
