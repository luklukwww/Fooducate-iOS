import Foundation

class ChatService {
    private let mixraiKey: String
    private let deepseekKey: String
    private let mixraiURL = URL(string: "https://api.mixrai.com/v1/chat/completions")!
    private let deepseekURL = URL(string: "https://api.deepseek.ai/v1/chat/completions")!
    
    init(mixraiKey: String, deepseekKey: String) {
        self.mixraiKey = mixraiKey
        self.deepseekKey = deepseekKey
    }
    
    func sendMessage(_ message: String, provider: APIProvider = .mixrai) async throws -> String {
        let apiKey = provider == .mixrai ? mixraiKey : deepseekKey
        guard !apiKey.isEmpty else {
            throw ChatError.missingAPIKey(provider: provider)
        }
        
        let requestData: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are GPT-3.5, a large language model trained by OpenAI. You are helpful, creative, clever, and very friendly."],
                ["role": "user", "content": message]
            ],
            "temperature": 0.7
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            throw ChatError.jsonEncodingFailed
        }
        
        let url = provider == .mixrai ? mixraiURL : deepseekURL
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw ChatError.apiError(message: message)
                }
                throw ChatError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonResponse["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ChatError.invalidResponse
        }
        
        return content
    }
    
    func sendMessageWithImage(_ message: String, base64Image: String, provider: APIProvider = .mixrai) async throws -> String {
        let apiKey = provider == .mixrai ? mixraiKey : deepseekKey
        guard !apiKey.isEmpty else {
            throw ChatError.missingAPIKey(provider: provider)
        }
        
        // Create the content array with text and image parts
        let content: [[String: Any]] = [
            ["type": "text", "text": message],
            [
                "type": "image_url", 
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)"
                ]
            ]
        ]
        
        // Create the request JSON
        let requestData: [String: Any] = [
            "model": "gpt-4o",  // Use GPT-4o for vision capabilities
            "messages": [
                [
                    "role": "user", 
                    "content": content
                ]
            ],
            "temperature": 0.7
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            throw ChatError.jsonEncodingFailed
        }
        
        let url = provider == .mixrai ? mixraiURL : deepseekURL
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw ChatError.apiError(message: message)
                }
                throw ChatError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonResponse["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ChatError.invalidResponse
        }
        
        return content
    }
}

enum APIProvider {
    case mixrai
    case deepseek
    
    var name: String {
        switch self {
        case .mixrai: return "MIXRAI"
        case .deepseek: return "DeepSeek"
        }
    }
}

enum ChatError: Error, LocalizedError {
    case jsonEncodingFailed
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)
    case missingAPIKey(provider: APIProvider)
    
    var errorDescription: String? {
        switch self {
        case .jsonEncodingFailed:
            return "JSON encoding failed"
        case .invalidResponse:
            return "Invalid response format"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .apiError(let message):
            return "API error: \(message)"
        case .missingAPIKey(let provider):
            return "\(provider.name) API key not set"
        }
    }
} 
