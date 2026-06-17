import StoreKit
import SwiftUI

// Moon Dog shared pattern. Canonical copy: /moondog/patterns/ReviewPrompter.swift
// Drop this file into the app's source folder and attach `.reviewPrompter()`
// to the root view in <App>App.swift.
//
// Asks for an App Store rating only after the user has genuinely engaged:
//   • at least `launchThreshold` DISTINCT cold launches — returning from the
//     app switcher, Control Center, or a StoreKit sheet does NOT count, so the
//     prompt can never appear on first launch or during onboarding, AND
//   • at least `minDaysSinceFirstLaunch` days since the very first launch,
//   • at most once per app version.
// This satisfies App Store Review Guideline 5.6.3 (no rating request before the
// user understands the app's value). The system additionally caps prompts at 3
// per year. Skipped entirely under UI tests / screenshot capture (any launch
// argument containing "UITest" or "screenshot").
struct ReviewPrompterModifier: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("review.launchCount") private var launchCount = 0
    @AppStorage("review.firstLaunchAt") private var firstLaunchAt = 0.0
    @AppStorage("review.lastPromptedVersion") private var lastPromptedVersion = ""

    // Resets on every cold launch, so a launch is counted at most once no
    // matter how many times the app is foregrounded within that process.
    @State private var countedThisLaunch = false

    private static let launchThreshold = 4
    private static let minDaysSinceFirstLaunch = 2.0

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            guard phase == .active, !countedThisLaunch else { return }
            countedThisLaunch = true
            launchCount += 1
            if firstLaunchAt == 0 {
                firstLaunchAt = Date().timeIntervalSince1970
            }
            promptIfEarned()
        }
    }

    @MainActor
    private func promptIfEarned() {
        let isTestRun = CommandLine.arguments.contains {
            $0.localizedCaseInsensitiveContains("uitest") || $0.localizedCaseInsensitiveContains("screenshot")
        }
        guard !isTestRun else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let daysSinceFirstLaunch = (Date().timeIntervalSince1970 - firstLaunchAt) / 86_400
        guard launchCount >= Self.launchThreshold,
              daysSinceFirstLaunch >= Self.minDaysSinceFirstLaunch,
              lastPromptedVersion != version else { return }
        lastPromptedVersion = version
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            requestReview()
        }
    }
}

extension View {
    func reviewPrompter() -> some View {
        modifier(ReviewPrompterModifier())
    }
}
