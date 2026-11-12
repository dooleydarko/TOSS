import Foundation
#if canImport(TossSchema)
import TossSchema
#endif

public struct HandoffDiff: Equatable {
    public var previousRevision: Int
    public var currentRevision: Int
    public var addedRequirements: [String]
    public var newlyCompletedActions: [String]
    public var objectiveChanged: Bool

    public init(previous: TossHandoff, current: TossHandoff) {
        self.previousRevision = previous.revision
        self.currentRevision = current.revision
        self.addedRequirements = current.requirements.filter { !previous.requirements.contains($0) }
        self.newlyCompletedActions = current.completed.filter { !previous.completed.contains($0) }
        self.objectiveChanged = (previous.objective != current.objective)
    }
}

public final class TossHistoryEngine {
    private var handoffsById: [String: TossHandoff] = [:]
    private var projectRevisions: [String: [TossHandoff]] = [:]
    private let storageURL: URL

    public init(storageURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("toss_history.json")) {
        self.storageURL = storageURL
        loadFromDisk()
    }

    public func recordHandoff(_ handoff: TossHandoff) {
        handoffsById[handoff.handoffId] = handoff

        var list = projectRevisions[handoff.projectId] ?? []
        if let existingIdx = list.firstIndex(where: { $0.handoffId == handoff.handoffId }) {
            list[existingIdx] = handoff
        } else {
            list.append(handoff)
        }
        list.sort(by: { $0.revision < $1.revision })
        projectRevisions[handoff.projectId] = list

        persistToDisk()
    }

    public func createNextRevision(from existing: TossHandoff, newRequirements: [String] = [], completedActions: [String] = []) -> TossHandoff {
        var updated = existing
        updated.revision += 1
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        if !newRequirements.isEmpty {
            updated.requirements.append(contentsOf: newRequirements)
        }
        if !completedActions.isEmpty {
            updated.completed.append(contentsOf: completedActions)
            updated.nextActions.removeAll(where: { completedActions.contains($0) })
        }
        recordHandoff(updated)
        return updated
    }

    public func history(forProjectId projectId: String) -> [TossHandoff] {
        return projectRevisions[projectId] ?? []
    }

    public func search(query: String) -> [TossHandoff] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return Array(handoffsById.values).sorted(by: { $0.updatedAt > $1.updatedAt })
        }
        let q = query.lowercased()
        return handoffsById.values.filter { handoff in
            handoff.title.lowercased().contains(q) ||
            handoff.objective.lowercased().contains(q) ||
            handoff.context.lowercased().contains(q) ||
            handoff.requirements.contains(where: { $0.lowercased().contains(q) }) ||
            handoff.nextActions.contains(where: { $0.lowercased().contains(q) })
        }.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    private func persistToDisk() {
        let all = Array(handoffsById.values)
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: storageURL)
        }
    }

    private func loadFromDisk() {
        if let data = try? Data(contentsOf: storageURL),
           let all = try? JSONDecoder().decode([TossHandoff].self, from: data) {
            for item in all {
                handoffsById[item.handoffId] = item
                var list = projectRevisions[item.projectId] ?? []
                list.append(item)
                projectRevisions[item.projectId] = list
            }
        }
    }
}
