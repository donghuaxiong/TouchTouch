import AppKit

@MainActor
final class HapticManager {
    func perform(intensity: Double) {
        let pulseCount = max(1, min(3, Int(intensity.rounded())))
        for index in 0..<pulseCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.045) {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .generic,
                    performanceTime: .now
                )
            }
        }
    }
}
