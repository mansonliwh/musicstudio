import Foundation

struct APIConfig {
    let apiKey: String

    var headers: [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
    }

    // MARK: - Replicate Music Endpoints (minimax/music-1.5)
    var musicSubmitEndpoint: URL {
        URL(string: "https://api.replicate.com/v1/models/minimax/music-1.5/predictions")!
    }

    // MARK: - Replicate RVC Endpoints (zsxkib/realistic-voice-cloning)
    var rvcEndpoint: URL {
        URL(string: "https://api.replicate.com/v1/models/zsxkib/realistic-voice-cloning/predictions")!
    }

    // MARK: - Replicate Poll Endpoint
    func pollEndpoint(predictionId: String) -> URL {
        URL(string: "https://api.replicate.com/v1/predictions/\(predictionId)")!
    }
}
