import Foundation

public struct TossRepository: Codable, Equatable {
    public var url: String?
    public var branch: String?
    public var commit: String?

    public init(url: String? = nil, branch: String? = nil, commit: String? = nil) {
        self.url = url
        self.branch = branch
        self.commit = commit
    }
}

public struct TossAttachment: Codable, Equatable {
    public var filename: String
    public var contentType: String
    public var sizeBytes: Int
    public var checksumSha256: String?

    public init(filename: String, contentType: String, sizeBytes: Int, checksumSha256: String? = nil) {
        self.filename = filename
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.checksumSha256 = checksumSha256
    }
}

public struct TossSource: Codable, Equatable {
    public var type: SourceType
    public var transcriptAvailable: Bool
    public var rawInput: String?

    public enum SourceType: String, Codable {
        case voice
        case text
        case edited
    }

    public init(type: SourceType, transcriptAvailable: Bool = false, rawInput: String? = nil) {
        self.type = type
        self.transcriptAvailable = transcriptAvailable
        self.rawInput = rawInput
    }
}

public enum TossDestination: String, Codable, CaseIterable {
    case antigravity
    case gpt
    case claude
    case generic
}

public struct TossHandoff: Codable, Equatable, Identifiable {
    public static let currentSchemaVersion = "1.0.0"

    public var id: String { handoffId }
    public var schemaVersion: String
    public var handoffId: String
    public var projectId: String
    public var title: String
    public var createdAt: String
    public var updatedAt: String
    public var revision: Int
    public var destination: TossDestination
    public var objective: String
    public var context: String
    public var requirements: [String]
    public var constraints: [String]
    public var completed: [String]
    public var nextActions: [String]
    public var knownIssues: [String]
    public var repository: TossRepository?
    public var attachments: [TossAttachment]
    public var source: TossSource

    public init(
        schemaVersion: String = TossHandoff.currentSchemaVersion,
        handoffId: String = UUID().uuidString.lowercased(),
        projectId: String = UUID().uuidString.lowercased(),
        title: String,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        updatedAt: String = ISO8601DateFormatter().string(from: Date()),
        revision: Int = 1,
        destination: TossDestination = .antigravity,
        objective: String,
        context: String,
        requirements: [String] = [],
        constraints: [String] = [],
        completed: [String] = [],
        nextActions: [String] = [],
        knownIssues: [String] = [],
        repository: TossRepository? = nil,
        attachments: [TossAttachment] = [],
        source: TossSource
    ) {
        self.schemaVersion = schemaVersion
        self.handoffId = handoffId
        self.projectId = projectId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.destination = destination
        self.objective = objective
        self.context = context
        self.requirements = requirements
        self.constraints = constraints
        self.completed = completed
        self.nextActions = nextActions
        self.knownIssues = knownIssues
        self.repository = repository
        self.attachments = attachments
        self.source = source
    }

    /// Validates core constraints of schema 1.0.0
    public func validate() throws {
        guard !schemaVersion.isEmpty else {
            throw TossValidationError.missingField("schemaVersion")
        }
        guard !handoffId.isEmpty else {
            throw TossValidationError.missingField("handoffId")
        }
        guard !projectId.isEmpty else {
            throw TossValidationError.missingField("projectId")
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TossValidationError.invalidField("title must not be empty")
        }
        guard revision >= 1 else {
            throw TossValidationError.invalidField("revision must be >= 1")
        }
    }

    /// Serializes handoff into clean human-readable Markdown
    public func toMarkdown() -> String {
        var lines: [String] = []
        lines.append("# \(title)")
        lines.append("**Schema Version:** \(schemaVersion) | **Revision:** \(revision) | **Destination:** \(destination.rawValue)")
        lines.append("**Handoff ID:** `\(handoffId)`")
        lines.append("**Project ID:** `\(projectId)`")
        lines.append("**Created At:** \(createdAt)")
        lines.append("\n---\n")

        lines.append("## Objective\n\(objective)\n")
        lines.append("## Context\n\(context)\n")

        lines.append("## Requirements")
        if requirements.isEmpty {
            lines.append("- *(None specified)*")
        } else {
            for req in requirements {
                lines.append("- \(req)")
            }
        }
        lines.append("")

        lines.append("## Constraints")
        if constraints.isEmpty {
            lines.append("- *(None specified)*")
        } else {
            for c in constraints {
                lines.append("- \(c)")
            }
        }
        lines.append("")

        lines.append("## Completed")
        if completed.isEmpty {
            lines.append("- *(None completed yet)*")
        } else {
            for comp in completed {
                lines.append("- \(comp)")
            }
        }
        lines.append("")

        lines.append("## Next Actions")
        if nextActions.isEmpty {
            lines.append("- *(None pending)*")
        } else {
            for (index, action) in nextActions.enumerated() {
                lines.append("\(index + 1). \(action)")
            }
        }
        lines.append("")

        lines.append("## Known Issues")
        if knownIssues.isEmpty {
            lines.append("*None reported in this revision.*")
        } else {
            for issue in knownIssues {
                lines.append("- ⚠️ \(issue)")
            }
        }
        lines.append("")

        lines.append("## Source Note")
        lines.append("- **Input Type:** \(source.type.rawValue)")
        if let raw = source.rawInput, !raw.isEmpty {
            lines.append("- **Raw Input:**")
            lines.append("> \(raw.replacingOccurrences(of: "\n", with: "\n> "))")
        }

        return lines.joined(separator: "\n")
    }

    /// Serializes handoff into formatted JSON
    public func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Deserializes and validates a handoff from JSON data
    public static func fromJSONData(_ data: Data) throws -> TossHandoff {
        let decoder = JSONDecoder()
        let handoff = try decoder.decode(TossHandoff.self, from: data)
        try handoff.validate()
        return handoff
    }
}

public enum TossValidationError: Error, CustomStringConvertible {
    case missingField(String)
    case invalidField(String)

    public var description: String {
        switch self {
        case .missingField(let f): return "Missing required schema field: \(f)"
        case .invalidField(let reason): return "Invalid schema field: \(reason)"
        }
    }
}
