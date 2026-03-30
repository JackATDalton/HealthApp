import Foundation

enum ClaudeAPIError: LocalizedError {
    case httpError(statusCode: Int, body: String)
    case invalidURL
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            // Extract message from Anthropic error JSON if present
            if let data = body.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = obj["error"] as? [String: Any],
               let msg = err["message"] as? String {
                return "API error \(code): \(msg)"
            }
            return "API error \(code)"
        case .invalidURL:
            return "Invalid API endpoint URL."
        case .emptyResponse:
            return "Claude returned an empty response."
        }
    }
}

enum ClaudeAPIClient {
    private static let endpoint = "https://api.anthropic.com/v1/messages"
    private static let anthropicVersion = "2023-06-01"

    /// Streams text deltas from the Claude Messages API.
    /// Yields each text chunk as it arrives. Throws on HTTP or network errors.
    static func stream(
        apiKey: String,
        model: String,
        system: String,
        userMessage: String,
        maxTokens: Int = 1500
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: endpoint) else {
                        continuation.finish(throwing: ClaudeAPIError.invalidURL)
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
                    request.setValue(anthropicVersion,   forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "content-type")

                    let body: [String: Any] = [
                        "model":      model,
                        "max_tokens": maxTokens,
                        "stream":     true,
                        "system":     system,
                        "messages":   [["role": "user", "content": userMessage]],
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    // Check HTTP status
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        var errorBody = ""
                        for try await byte in bytes {
                            errorBody.append(Character(UnicodeScalar(byte)))
                        }
                        continuation.finish(throwing: ClaudeAPIError.httpError(
                            statusCode: http.statusCode, body: errorBody
                        ))
                        return
                    }

                    var receivedAny = false

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard json != "[DONE]" else { break }
                        guard let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        // Only content_block_delta / text_delta events carry text
                        guard obj["type"] as? String == "content_block_delta",
                              let delta = obj["delta"] as? [String: Any],
                              delta["type"] as? String == "text_delta",
                              let text = delta["text"] as? String
                        else { continue }

                        receivedAny = true
                        continuation.yield(text)
                    }

                    if !receivedAny {
                        continuation.finish(throwing: ClaudeAPIError.emptyResponse)
                        return
                    }

                    continuation.finish()
                } catch let error as ClaudeAPIError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
