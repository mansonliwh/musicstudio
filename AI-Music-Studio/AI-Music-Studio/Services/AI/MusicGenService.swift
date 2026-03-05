import Foundation
import Combine

/// 音乐生成服务 (已弃用 - 请使用 SunoService)
/// UniAPI 的 Replicate 代理不支持 MusicGen，请改用 Suno API
@available(*, deprecated, message: "Use SunoService instead. UniAPI does not support MusicGen via Replicate proxy.")
class MusicGenService {
    private let apiClient = APIClient.shared

    func generateMusic(
        prompt: String,
        duration: Int = 30,
        model: MusicGenModel = .medium,
        apiKey: String,
        provider: APIProvider = .replicate,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        switch provider {
        case .replicate:
            generateWithReplicate(
                prompt: prompt,
                duration: duration,
                model: model,
                apiKey: apiKey,
                progress: progress,
                completion: completion
            )
        case .huggingface:
            generateWithHuggingFace(
                prompt: prompt,
                duration: duration,
                model: model,
                apiKey: apiKey,
                progress: progress,
                completion: completion
            )
        case .local:
            generateWithLocal(
                prompt: prompt,
                duration: duration,
                progress: progress,
                completion: completion
            )
        }
    }
    
    private func generateWithReplicate(
        prompt: String,
        duration: Int,
        model: MusicGenModel,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // UniAPI 格式: POST /v1/models/{model}/predictions
        // meta/musicgen 模型，URL 编码斜杠
        let modelName = "meta%2Fmusicgen"
        let url = URL(string: "https://api.uniapi.io/replicate/v1/models/\(modelName)/predictions")!

        let body: [String: Any] = [
            "input": [
                "prompt": prompt,
                "duration": duration,
                "model_version": model.rawValue.contains("small") ? "facebook/musicgen-small" : "facebook/musicgen-medium"
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // Debug: print response body for troubleshooting
            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                print("[MusicGen] Response: \(responseBody)")
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let responseInfo = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response data"
                completion(.failure(NSError(domain: "MusicGen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(responseInfo)"])))
                return
            }

            // Check for API error
            if let errorMsg = json["error"] as? String {
                completion(.failure(NSError(domain: "MusicGen", code: -1, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMsg)"])))
                return
            }

            guard let predictionId = json["id"] as? String else {
                completion(.failure(NSError(domain: "MusicGen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create prediction: \(json)"])))
                return
            }
            
            self.pollReplicateResult(
                predictionId: predictionId,
                apiKey: apiKey,
                progress: progress,
                completion: completion
            )
        }.resume()
    }
    
    private func pollReplicateResult(
        predictionId: String,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // UniAPI 格式: GET /v1/predictions/{task_id}
        let url = URL(string: "https://api.uniapi.io/replicate/v1/predictions/\(predictionId)")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        func poll() {
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Debug: print response body for troubleshooting
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("[MusicGen] Poll Response: \(responseBody)")
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let responseInfo = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response data"
                    completion(.failure(NSError(domain: "MusicGen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response: \(responseInfo)"])))
                    return
                }

                guard let status = json["status"] as? String else {
                    completion(.failure(NSError(domain: "MusicGen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing status in response: \(json)"])))
                    return
                }
                
                switch status {
                case "succeeded":
                    if let output = json["output"] as? String {
                        guard let audioURL = URL(string: output) else {
                            completion(.failure(NSError(domain: "MusicGen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio URL"])))
                            return
                        }
                        completion(.success(audioURL))
                    }
                case "failed", "canceled":
                    let errorMsg = (json["error"] as? String) ?? "Generation failed"
                    completion(.failure(NSError(domain: "MusicGen", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                case "processing", "starting":
                    progress(status, 0.5)
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                        poll()
                    }
                default:
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                        poll()
                    }
                }
            }.resume()
        }
        
        poll()
    }
    
    private func generateWithHuggingFace(
        prompt: String,
        duration: Int,
        model: MusicGenModel,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let url = URL(string: "https://api-inference.huggingface.co/models/\(model.rawValue)")!
        
        let body: [String: Any] = [
            "inputs": prompt,
            "parameters": [
                "duration": duration
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        progress("正在生成音乐...", 0.3)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let httpResponse = response as? HTTPURLResponse
            
            if httpResponse?.statusCode == 503 {
                progress("模型加载中，请稍候...", 0.5)
                DispatchQueue.global().asyncAfter(deadline: .now() + 20) {
                    self.generateWithHuggingFace(
                        prompt: prompt,
                        duration: duration,
                        model: model,
                        apiKey: apiKey,
                        progress: progress,
                        completion: completion
                    )
                }
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "MusicGen", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let audioURL = tempDir.appendingPathComponent("generated_\(UUID().uuidString).wav")
            
            do {
                try data.write(to: audioURL)
                completion(.success(audioURL))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func generateWithLocal(
        prompt: String,
        duration: Int,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let url = URL(string: "http://localhost:8000/generate")!
        
        let body: [String: Any] = [
            "prompt": prompt,
            "duration": duration
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        progress("正在本地生成音乐...", 0.3)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let audioPath = json["audio_path"] as? String else {
                completion(.failure(NSError(domain: "MusicGen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            let audioURL = URL(fileURLWithPath: audioPath)
            completion(.success(audioURL))
        }.resume()
    }
    
    private func getReplicateModelVersion(model: MusicGenModel) -> String {
        // meta/musicgen on Replicate - single version supports all model sizes
        // https://replicate.com/meta/musicgen
        return "671ac645ce5e552cc63a54a2bbff63fcf798043055d2dac5fc9e36a837eedcfb"
    }
}
