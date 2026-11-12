import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum TossModelKind: String, CaseIterable, Codable, Identifiable {
    case offline, gemini, openAI, claude, openRouter, compatible
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .offline: return "Offline formatter"
        case .gemini: return "Google Gemini"
        case .openAI: return "OpenAI"
        case .claude: return "Anthropic Claude"
        case .openRouter: return "OpenRouter"
        case .compatible: return "Compatible / local"
        }
    }
    public var defaultModel: String {
        switch self {
        case .offline: return ""
        case .gemini: return "gemini-2.5-flash"
        case .openRouter: return "openrouter/free"
        default: return ""
        }
    }
}

public struct TossRemoteProvider: AIProvider {
    public let kind: TossModelKind
    public let model: String
    private let key: String
    private let endpoint: String
    public var name: String { kind.label }
    public var isConfigured: Bool { !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (kind == .compatible || !key.isEmpty) }
    public init(kind: TossModelKind, model: String, key: String, endpoint: String = "") {
        self.kind = kind; self.model = model; self.key = key; self.endpoint = endpoint
    }
    private func endpointURL() throws -> URL {
        let address: String
        switch kind {
        case .openAI: address = "https://api.openai.com/v1/chat/completions"
        case .claude: address = "https://api.anthropic.com/v1/messages"
        case .openRouter: address = "https://openrouter.ai/api/v1/chat/completions"
        case .compatible: address = endpoint
        default: throw TossValidationError.invalidField("Unsupported remote provider")
        }
        guard let url = URL(string: address), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil, url.query == nil,
              url.scheme == "https" else {
            throw TossValidationError.invalidField("Enter a full HTTPS model endpoint. Use a secure tunnel for local servers.")
        }
        return url
    }
    public func health() async -> Bool { (try? endpointURL()) != nil && isConfigured }
    public func makeRequest(input: String, context: String) throws -> URLRequest {
        guard isConfigured else { throw TossValidationError.invalidField("Set a model ID and API key in Settings") }
        var request = URLRequest(url: try endpointURL())
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let notes = try GeminiAIProvider.notesJSON(input: input, context: context)
        let body: [String: Any]
        if kind == .claude {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = ["model": model, "max_tokens": 4096, "system": GeminiAIProvider.structuringPrompt,
                    "messages": [["role": "user", "content": notes]]]
        } else {
            if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
            body = ["model": model, "messages": [["role": "system", "content": GeminiAIProvider.structuringPrompt],
                                                ["role": "user", "content": notes]]]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    public func structure(input: String, context: String) async throws -> TossHandoff {
        let request = try makeRequest(input: input, context: context)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TossValidationError.invalidField("\(name) request failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)). Check model, quota and credentials.")
        }
        return try Self.decode(data, kind: kind, originalInput: input)
    }
    public static func decode(_ data: Data, kind: TossModelKind, originalInput: String) throws -> TossHandoff {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let raw: String?
        if kind == .claude {
            raw = (root?["content"] as? [[String: Any]])?.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
        } else {
            raw = ((root?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String
        }
        guard var json = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !json.isEmpty else {
            throw TossValidationError.invalidField("Model returned no handoff text")
        }
        if json.hasPrefix("```"), json.hasSuffix("```"), let line = json.firstIndex(of: "\n") {
            json = String(json[json.index(after: line)...].dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var handoff = try TossHandoff.fromJSONData(Data(json.utf8))
        guard handoff.schemaVersion == TossHandoff.currentSchemaVersion else { throw TossValidationError.invalidField("Unexpected schema version") }
        handoff.source = TossSource(type: .text, rawInput: originalInput)
        return handoff
    }
}
