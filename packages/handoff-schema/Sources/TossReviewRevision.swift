import Foundation

/// Review edits are made against a saved snapshot, never against the raw transcript.
public enum TossReviewRevision {
    public static func edited(_ draft: TossHandoff, from original: TossHandoff, latestRevision: Int) throws -> TossHandoff {
        guard draft.handoffId == original.handoffId, draft.projectId == original.projectId,
              original.revision == latestRevision else {
            throw TossValidationError.invalidField("This handoff has a newer revision. Reopen it before editing.")
        }
        var result = original
        result.title = draft.title
        result.objective = draft.objective
        result.context = draft.context
        result.requirements = draft.requirements
        result.constraints = draft.constraints
        result.completed = draft.completed
        result.nextActions = draft.nextActions
        result.knownIssues = draft.knownIssues
        result.destination = draft.destination
        try result.validate()
        if result == original { return original }
        result.revision = latestRevision + 1
        result.updatedAt = ISO8601DateFormatter().string(from: Date())
        return result
    }

    public static func upsert(_ handoff: TossHandoff, into snapshots: [TossHandoff]) -> [TossHandoff] {
        var result = snapshots
        if let index = result.firstIndex(where: { $0.handoffId == handoff.handoffId && $0.revision == handoff.revision }) {
            result[index] = handoff
        } else {
            result.insert(handoff, at: 0)
        }
        return result
    }

    public static func latest(in snapshots: [TossHandoff]) -> [TossHandoff] {
        var seen = Set<String>()
        return snapshots.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            if $0.revision != $1.revision { return $0.revision > $1.revision }
            return $0.handoffId < $1.handoffId
        }.filter { candidate in
            guard !snapshots.contains(where: { $0.handoffId == candidate.handoffId && $0.revision > candidate.revision }) else { return false }
            return seen.insert(candidate.handoffId).inserted
        }
    }
}
