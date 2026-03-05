import Foundation

struct APIConfig {
    let provider: APIProvider
    let baseURL: URL
    let apiKey: String

    // MARK: - Suno API Endpoints
    var sunoSubmitEndpoint: URL {
        return URL(string: "https://api.uniapi.io/suno/submit/music")!
    }

    var sunoFetchEndpoint: URL {
        return URL(string: "https://api.uniapi.io/suno/fetch")!
    }

    // MARK: - Legacy MusicGen Endpoints (deprecated)
    var musicGenEndpoint: URL {
        switch provider {
        case .replicate:
            // UniAPI 格式: /v1/models/{model}/predictions
            return URL(string: "https://api.uniapi.io/replicate/v1/models/meta%2Fmusicgen/predictions")!
        case .huggingface:
            return baseURL.appendingPathComponent("models/facebook/musicgen-small")
        case .local:
            return baseURL.appendingPathComponent("generate")
        }
    }

    var rvcEndpoint: URL {
        switch provider {
        case .replicate:
            // UniAPI 格式: /v1/models/{model}/predictions
            return URL(string: "https://api.uniapi.io/replicate/v1/models/rvc/predictions")!
        case .huggingface:
            return baseURL.appendingPathComponent("models/rvc-model")
        case .local:
            return baseURL.appendingPathComponent("convert")
        }
    }

    // 轮询结果端点
    func pollEndpoint(predictionId: String) -> URL {
        switch provider {
        case .replicate:
            // UniAPI 格式: /v1/predictions/{task_id}
            return URL(string: "https://api.uniapi.io/replicate/v1/predictions/\(predictionId)")!
        case .huggingface, .local:
            return baseURL.appendingPathComponent("predictions/\(predictionId)")
        }
    }
    
    var headers: [String: String] {
        switch provider {
        case .replicate:
            // UniAPI 使用 Bearer 认证
            return [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ]
        case .huggingface:
            return [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ]
        case .local:
            return ["Content-Type": "application/json"]
        }
    }
    
    static func createBaseURL(for provider: APIProvider) -> URL {
        switch provider {
        case .replicate:
            // 使用 UniAPI 中转站点
            return URL(string: "https://api.uniapi.io/replicate/v1/")!
        case .huggingface:
            return URL(string: "https://api-inference.huggingface.co/")!
        case .local:
            return URL(string: "http://localhost:8000/")!
        }
    }
}

enum MusicGenModel: String, CaseIterable {
    case small = "facebook/musicgen-small"
    case medium = "facebook/musicgen-medium"
    case large = "facebook/musicgen-large"
    
    var displayName: String {
        switch self {
        case .small: return "Small (快速)"
        case .medium: return "Medium (平衡)"
        case .large: return "Large (高质量)"
        }
    }
}

enum RVCModel: String, CaseIterable {
    case v1 = "rvc-v1"
    case v2 = "rvc-v2"
    
    var displayName: String {
        switch self {
        case .v1: return "RVC v1"
        case .v2: return "RVC v2 (推荐)"
        }
    }
}
