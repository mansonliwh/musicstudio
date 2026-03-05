import Foundation
import Combine

class RVCService {
    
    enum RVCPitch: Int {
        case veryLow = -12
        case low = -6
        case normal = 0
        case high = 6
        case veryHigh = 12
    }
    
    func cloneVoice(
        audioFileURL: URL,
        outputName: String,
        apiKey: String,
        provider: APIProvider = .replicate,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        switch provider {
        case .replicate:
            cloneWithReplicate(
                audioFileURL: audioFileURL,
                outputName: outputName,
                apiKey: apiKey,
                progress: progress,
                completion: completion
            )
        case .huggingface:
            cloneWithHuggingFace(
                audioFileURL: audioFileURL,
                outputName: outputName,
                apiKey: apiKey,
                progress: progress,
                completion: completion
            )
        case .local:
            cloneWithLocal(
                audioFileURL: audioFileURL,
                outputName: outputName,
                progress: progress,
                completion: completion
            )
        }
    }
    
    func convertVoice(
        sourceAudioURL: URL,
        voiceModel: VoiceModel,
        pitch: RVCPitch = .normal,
        apiKey: String,
        provider: APIProvider = .replicate,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let modelPath = voiceModel.modelFilePath else {
            completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "声音模型未训练"])))
            return
        }
        
        switch provider {
        case .replicate:
            convertWithReplicate(
                sourceAudioURL: sourceAudioURL,
                modelPath: modelPath,
                pitch: pitch,
                apiKey: apiKey,
                progress: progress,
                completion: completion
            )
        case .huggingface:
            convertWithHuggingFace(
                sourceAudioURL: sourceAudioURL,
                modelPath: modelPath,
                pitch: pitch,
                apiKey: apiKey,
                progress: progress,
                completion: completion
            )
        case .local:
            convertWithLocal(
                sourceAudioURL: sourceAudioURL,
                modelPath: modelPath,
                pitch: pitch,
                progress: progress,
                completion: completion
            )
        }
    }
    
    private func cloneWithReplicate(
        audioFileURL: URL,
        outputName: String,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        progress("正在上传音频文件...", 0.1)
        
        uploadFileToReplicate(
            fileURL: audioFileURL,
            apiKey: apiKey
        ) { result in
            switch result {
            case .success(let uploadedURL):
                progress("正在训练声音模型...", 0.3)
                self.runReplicateRVC(
                    audioURL: uploadedURL,
                    task: "train",
                    apiKey: apiKey,
                    progress: progress,
                    completion: completion
                )
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func convertWithReplicate(
        sourceAudioURL: URL,
        modelPath: URL,
        pitch: RVCPitch,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        progress("正在上传音频文件...", 0.1)
        
        uploadFileToReplicate(
            fileURL: sourceAudioURL,
            apiKey: apiKey
        ) { result in
            switch result {
            case .success(let uploadedURL):
                progress("正在进行声音转换...", 0.3)
                self.runReplicateRVCConversion(
                    audioURL: uploadedURL,
                    modelPath: modelPath,
                    pitch: pitch,
                    apiKey: apiKey,
                    progress: progress,
                    completion: completion
                )
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func uploadFileToReplicate(
        fileURL: URL,
        apiKey: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        do {
            let fileData = try Data(contentsOf: fileURL)
            let base64String = fileData.base64EncodedString()
            let ext = fileURL.pathExtension.lowercased()
            let mimeType: String
            switch ext {
            case "mp3":
                mimeType = "audio/mpeg"
            case "m4a":
                mimeType = "audio/mp4"
            case "ogg":
                mimeType = "audio/ogg"
            default:
                mimeType = "audio/wav"
            }
            
            // 创建 data URI
            let dataURIString = "data:\(mimeType);base64,\(base64String)"
            guard let dataURI = URL(string: dataURIString) else {
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建Data URI"])))
                return
            }
            
            completion(.success(dataURI))
        } catch {
            completion(.failure(error))
        }
    }
    
    private func runReplicateRVC(
        audioURL: URL,
        task: String,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // UniAPI 格式: POST /v1/models/{model}/predictions
        // RVC 模型
        let modelName = "rvc"
        let url = URL(string: "https://api.uniapi.io/replicate/v1/models/\(modelName)/predictions")!

        let body: [String: Any] = [
            "input": [
                "audio": audioURL.absoluteString,
                "task": task
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // Debug: print response body for troubleshooting
            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                print("[RVC] Response: \(responseBody)")
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let responseInfo = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response data"
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "解析响应失败: \(responseInfo)"])))
                return
            }

            // Check for API error
            if let errorMsg = json["error"] as? String {
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "API 错误: \(errorMsg)"])))
                return
            }

            guard let predictionId = json["id"] as? String else {
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "创建预测失败: \(json)"])))
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

    private func runReplicateRVCConversion(
        audioURL: URL,
        modelPath: URL,
        pitch: RVCPitch,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // UniAPI 格式: POST /v1/models/{model}/predictions
        // RVC 模型
        let modelName = "rvc"
        let url = URL(string: "https://api.uniapi.io/replicate/v1/models/\(modelName)/predictions")!

        let body: [String: Any] = [
            "input": [
                "audio": audioURL.absoluteString,
                "model": modelPath.absoluteString,
                "pitch": pitch.rawValue
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // Debug: print response body for troubleshooting
            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                print("[RVC] Conversion Response: \(responseBody)")
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let responseInfo = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response data"
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "解析响应失败: \(responseInfo)"])))
                return
            }

            // Check for API error
            if let errorMsg = json["error"] as? String {
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "API 错误: \(errorMsg)"])))
                return
            }

            guard let predictionId = json["id"] as? String else {
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "创建预测失败: \(json)"])))
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
                    print("[RVC] Poll Response: \(responseBody)")
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let responseInfo = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response data"
                    completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效响应: \(responseInfo)"])))
                    return
                }

                guard let status = json["status"] as? String else {
                    completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应缺少状态: \(json)"])))
                    return
                }
                
                switch status {
                case "succeeded":
                    if let output = json["output"] as? String {
                        guard let audioURL = URL(string: output) else {
                            completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效音频URL"])))
                            return
                        }
                        completion(.success(audioURL))
                    }
                case "failed", "canceled":
                    let errorMsg = (json["error"] as? String) ?? "转换失败"
                    completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                case "processing", "starting":
                    progress("处理中...", 0.7)
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
    
    private func cloneWithHuggingFace(
        audioFileURL: URL,
        outputName: String,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        progress("HuggingFace RVC 暂不支持声音克隆", 0)
        completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "暂不支持"])))
    }
    
    private func cloneWithLocal(
        audioFileURL: URL,
        outputName: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let url = URL(string: "http://localhost:8000/train")!
        
        let body: [String: Any] = [
            "audio_path": audioFileURL.path,
            "name": outputName
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        progress("正在本地训练声音模型...", 0.3)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelPath = json["model_path"] as? String else {
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "训练失败"])))
                return
            }
            
            let modelURL = URL(fileURLWithPath: modelPath)
            completion(.success(modelURL))
        }.resume()
    }
    
    private func convertWithHuggingFace(
        sourceAudioURL: URL,
        modelPath: URL,
        pitch: RVCPitch,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        progress("HuggingFace RVC 暂不支持声音转换", 0)
        completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "暂不支持"])))
    }
    
    private func convertWithLocal(
        sourceAudioURL: URL,
        modelPath: URL,
        pitch: RVCPitch,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let url = URL(string: "http://localhost:8000/convert")!
        
        let body: [String: Any] = [
            "source_audio": sourceAudioURL.path,
            "model_path": modelPath.path,
            "pitch": pitch.rawValue
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        progress("正在进行本地声音转换...", 0.3)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let outputPath = json["output_path"] as? String else {
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "转换失败"])))
                return
            }
            
            let outputURL = URL(fileURLWithPath: outputPath)
            completion(.success(outputURL))
        }.resume()
    }
}
