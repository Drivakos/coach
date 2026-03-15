import Foundation

/// Shared infrastructure for Perplexity API calls from the iOS client (food search).
enum PerplexityClient {

    static let apiKey: String  = Bundle.main.infoDictionary?["PERPLEXITY_API_KEY"] as? String ?? ""
    static let endpoint        = URL(string: "https://api.perplexity.ai/chat/completions")!
    static let decoder         = JSONDecoder()

    // MARK: - Request

    static func buildRequest(
        messages:    [[String: Any]],
        model:       String = "sonar",
        temperature: Double = 0.1,
        timeout:     TimeInterval = 30
    ) throws -> URLRequest {
        let body: [String: Any] = ["model": model, "messages": messages, "temperature": temperature]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)",   forHTTPHeaderField: "Authorization")
        req.setValue("application/json",   forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    // MARK: - Response

    struct Response: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }

    /// Extracts the first complete JSON object (`{…}`) from content that may be
    /// wrapped in markdown fences or preceded by prose.
    static func extractJSON(from content: String) throws -> Data {
        guard let start = content.firstIndex(of: "{"),
              let end   = content.lastIndex(of: "}"),
              let data  = String(content[start...end]).data(using: .utf8)
        else { throw PerplexityClientError.noJSONFound }
        return data
    }
}

enum PerplexityClientError: LocalizedError {
    case noJSONFound
    var errorDescription: String? { "Could not locate JSON in AI response." }
}
