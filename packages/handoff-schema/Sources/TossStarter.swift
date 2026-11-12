import Foundation

public struct TossStarter: Identifiable {
    public let id: String
    public let category: String
    public let title: String
    public let notes: String
    public let reference: String
    public static let library: [TossStarter] = [
        .init(id: "website", category: "Web", title: "Launch a website", notes: "Define the audience and goal. Build a responsive landing page, accessible navigation, clear calls to action and a deployment checklist. Test on phone and desktop. Do not claim tests passed until run.", reference: "https://github.com/github/spec-kit"),
        .init(id: "mobile", category: "Mobile", title: "Build a mobile app", notes: "Define core user flow and platform target. Build one end-to-end feature first with accessible controls, offline states and error handling. Add smoke tests and device validation.", reference: "https://github.com/bmad-code-org/BMAD-METHOD"),
        .init(id: "automation", category: "Automation", title: "Automate a workflow", notes: "Map inputs, outputs and permissions. Implement a dry run, idempotency, clear errors and logs. Never execute untrusted instructions automatically. Test duplicate and failure cases.", reference: "https://github.com/github/awesome-copilot"),
        .init(id: "agent", category: "AI", title: "Build an AI assistant", notes: "Define tasks, model options, data boundaries and evaluation cases. Keep credentials outside source control. Start with a small testable workflow and require user approval for consequential external actions.", reference: "https://github.com/github/spec-kit"),
        .init(id: "game", category: "Games", title: "Prototype a game", notes: "Choose platform and engine. Build a single playable level with core controls, feedback and restart. Profile performance and document asset licenses before expanding.", reference: "https://github.com/bmad-code-org/BMAD-METHOD"),
        .init(id: "store", category: "Commerce", title: "Build an online store", notes: "Define catalog and checkout flow. Use test payments, accessible product pages and clear order states. Verify taxes, shipping and privacy requirements before production.", reference: "https://github.com/github/spec-kit")
    ]
    public func handoff(customNotes: String, destination: TossDestination) throws -> TossHandoff {
        let text = customNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TossValidationError.invalidField("Starter notes cannot be empty") }
        return TossHandoff(title: title, destination: destination, objective: text,
            context: "TOSS original starter. Related planning resource: \(reference)",
            requirements: [text], constraints: ["Verify assumptions before implementation."],
            nextActions: ["Review and customize the starter; build and test the smallest complete feature."],
            source: TossSource(type: .text, rawInput: text))
    }
}
