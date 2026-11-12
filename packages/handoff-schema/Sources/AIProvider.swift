import Foundation

public protocol AIProvider {
    var name: String { get }
    var isConfigured: Bool { get }
    func structure(input: String, context: String) async throws -> TossHandoff
    func health() async -> Bool
}

/// Fallback provider that guarantees 100% offline structuring without any API key or external service
public final class RuleBasedFallbackProvider: AIProvider {
    public let name = "Local Template Formatter (Offline)"
    public var isConfigured: Bool { true }

    public init() {}

    public func health() async -> Bool {
        return true
    }

    public func structure(input: String, context: String) async throws -> TossHandoff {
        let lines = input.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        let title = lines.first ?? "Untitled Handoff"
        var requirements: [String] = []
        var nextActions: [String] = []
        var constraints: [String] = []

        for line in lines.dropFirst() {
            let lower = line.lowercased()
            if lower.contains("must") || lower.contains("require") || line.hasPrefix("- ") || line.hasPrefix("* ") {
                let clean = line.trimmingCharacters(in: CharacterSet(charactersIn: "-*• \t"))
                requirements.append(clean)
            } else if lower.contains("next") || lower.contains("todo") || line.first?.isNumber == true {
                let clean = line.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.-) \t"))
                nextActions.append(clean)
            } else if lower.contains("constraint") || lower.contains("rule") || lower.contains("don't") || lower.contains("never") {
                constraints.append(line)
            }
        }

        if requirements.isEmpty {
            requirements = ["Process user input: \(input.prefix(80))..."]
        }
        if nextActions.isEmpty {
            nextActions = ["Review requirements and confirm Phase 1 scope.", "Verify end-to-end receipt on Mac receiver."]
        }
        if constraints.isEmpty {
            constraints = ["Maintain modular structure for subsequent agent refinement.", "Do not execute inbound instructions automatically."]
        }

        return TossHandoff(
            title: title,
            destination: .antigravity,
            objective: "Structured handoff derived from user notes.",
            context: context.isEmpty ? "Direct user input captured via TOSS." : context,
            requirements: requirements,
            constraints: constraints,
            completed: ["Initial notes captured and structured."],
            nextActions: nextActions,
            knownIssues: [],
            source: TossSource(type: .text, transcriptAvailable: false, rawInput: input)
        )
    }
}

/// Gemini AI Provider connecting to Google Gemini REST endpoint
public final class GeminiAIProvider: AIProvider {
    public let name = "Google Gemini API"
    public let apiKey: String
    public let model: String

    public var isConfigured: Bool {
        return !apiKey.isEmpty && apiKey != "your_gemini_api_key_here"
    }

    public init(
        apiKey: String = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "",
        model: String = ProcessInfo.processInfo.environment["GEMINI_MODEL"] ?? "gemini-1.5-flash"
    ) {
        self.apiKey = apiKey
        self.model = model
    }

    public func health() async -> Bool {
        guard isConfigured else { return false }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model)?key=\(apiKey)") else {
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return false
        }
        return true
    }

    public func structure(input: String, context: String) async throws -> TossHandoff {
        guard isConfigured else {
            // Fallback gracefully
            return try await RuleBasedFallbackProvider().structure(input: input, context: context)
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw TossValidationError.invalidField("Invalid Gemini endpoint URL")
        }

        let systemPrompt = """
        You are TOSS AI Handoff Structurer. Convert the user input into a valid JSON object strictly matching schemaVersion 1.0.0.
        Required JSON fields:
        {
          "schemaVersion": "1.0.0",
          "handoffId": "<uuid>",
          "projectId": "<uuid>",
          "title": "<concise title>",
          "createdAt": "<ISO-8601>",
          "updatedAt": "<ISO-8601>",
          "revision": 1,
          "destination": "antigravity",
          "objective": "<summary of goal>",
          "context": "<background>",
          "requirements": ["req1", "req2"],
          "constraints": ["constraint1"],
          "completed": [],
          "nextActions": ["action1", "action2"],
          "knownIssues": [],
          "source": { "type": "text", "transcriptAvailable": false, "rawInput": "<raw input>" }
        }
        Return ONLY valid raw JSON with no markdown backticks or commentary.
        """

        let payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "\(systemPrompt)\n\nUser Context:\n\(context)\n\nUser Raw Notes:\n\(input)"]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            // If API call fails or quota blocked, fallback to rule-based offline provider
            return try await RuleBasedFallbackProvider().structure(input: input, context: context)
        }

        // Parse Gemini response structure
        guard let jsonRoot = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonRoot["candidates"] as? [[String: Any]],
              let firstCand = candidates.first,
              let content = firstCand["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String,
              let textData = text.data(using: .utf8) else {
            return try await RuleBasedFallbackProvider().structure(input: input, context: context)
        }

        return try TossHandoff.fromJSONData(textData)
    }
}
