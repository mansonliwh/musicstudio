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

    private let submitURL = URL(string: "https://api.replicate.com/v1/models/zsxkib/realistic-voice-cloning/predictions")!

    func cloneVoice(
        audioFileURL: URL,
        outputName: String,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        progress("正在上传音频文件...", 0.1)

        let dataURI: URL
        do {
            dataURI = try createDataURI(from: audioFileURL)
        } catch {
            completion(.failure(error))
            return
        }

        progress("正在训练声音模型...", 0.3)

        let body: [String: Any] = [
            "input": [
                "song_input": dataURI.absoluteString,
                "rvc_model": "CUSTOM",
                "custom_rvc_model_download_url": "",
                "pitch_change": "no-change",
                "index_rate": 0.5,
                "filter_radius": 3,
                "rms_mix_rate": 0.25,
                "pitch_detection_algorithm": "rmvpe",
                "crepe_hop_length": 128,
                "protect": 0.33,
                "main_vocals_volume_change": 0,
                "backup_vocals_volume_change": 0,
                "instrumental_volume_change": 0,
                "pitch_change_all": 0,
                "reverb_size": 0.15,
                "reverb_wetness": 0.2,
                "reverb_dryness": 0.8,
                "reverb_damping": 0.7,
                "output_format": "mp3"
            ]
        ]

        submitPrediction(body: body, apiKey: apiKey, progress: progress, completion: completion)
    }

    func convertVoice(
        sourceAudioURL: URL,
        voiceModel: VoiceModel,
        pitch: RVCPitch = .normal,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let modelPath = voiceModel.modelFilePath else {
            completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "声音模型未训练"])))
            return
        }

        progress("正在上传音频文件...", 0.1)

        let dataURI: URL
        do {
            dataURI = try createDataURI(from: sourceAudioURL)
        } catch {
            completion(.failure(error))
            return
        }

        progress("正在进行声音转换...", 0.3)

        let pitchChange: String
        switch pitch {
        case .veryLow: pitchChange = "octave-down"
        case .low: pitchChange = "down"
        case .normal: pitchChange = "no-change"
        case .high: pitchChange = "up"
        case .veryHigh: pitchChange = "octave-up"
        }

        let body: [String: Any] = [
            "input": [
                "song_input": dataURI.absoluteString,
                "rvc_model": "CUSTOM",
                "custom_rvc_model_download_url": modelPath.absoluteString,
                "pitch_change": pitchChange,
                "index_rate": 0.5,
                "filter_radius": 3,
                "rms_mix_rate": 0.25,
                "pitch_detection_algorithm": "rmvpe",
                "crepe_hop_length": 128,
                "protect": 0.33,
                "main_vocals_volume_change": 0,
                "backup_vocals_volume_change": 0,
                "instrumental_volume_change": 0,
                "pitch_change_all": pitch.rawValue,
                "reverb_size": 0.15,
                "reverb_wetness": 0.2,
                "reverb_dryness": 0.8,
                "reverb_damping": 0.7,
                "output_format": "mp3"
            ]
        ]

        submitPrediction(body: body, apiKey: apiKey, progress: progress, completion: completion)
    }

    // MARK: - Private

    private func createDataURI(from fileURL: URL) throws -> URL {
        let fileData = try Data(contentsOf: fileURL)
        let base64String = fileData.base64EncodedString()
        let ext = fileURL.pathExtension.lowercased()
        let mimeType: String
        switch ext {
        case "mp3": mimeType = "audio/mpeg"
        case "m4a": mimeType = "audio/mp4"
        case "ogg": mimeType = "audio/ogg"
        default:    mimeType = "audio/wav"
        }

        let dataURIString = "data:\(mimeType);base64,\(base64String)"
        guard let dataURI = URL(string: dataURIString) else {
            throw NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建Data URI"])
        }
        return dataURI
    }

    private func submitPrediction(
        body: [String: Any],
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        var request = URLRequest(url: submitURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                print("[RVC] Response: \(responseBody)")
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let info = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response data"
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "解析响应失败: \(info)"])))
                return
            }

            if let errorMsg = json["error"] as? String {
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "API 错误: \(errorMsg)"])))
                return
            }

            guard let predictionId = json["id"] as? String else {
                completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "创建预测失败: \(json)"])))
                return
            }

            self.pollResult(predictionId: predictionId, apiKey: apiKey, progress: progress, completion: completion)
        }.resume()
    }

    private func pollResult(
        predictionId: String,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let url = URL(string: "https://api.replicate.com/v1/predictions/\(predictionId)")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        func poll() {
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("[RVC] Poll Response: \(responseBody)")
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let info = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response data"
                    completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效响应: \(info)"])))
                    return
                }

                guard let status = json["status"] as? String else {
                    completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应缺少状态: \(json)"])))
                    return
                }

                switch status {
                case "succeeded":
                    if let output = json["output"] as? String,
                       let audioURL = URL(string: output) {
                        completion(.success(audioURL))
                    } else {
                        completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效音频URL"])))
                    }
                case "failed", "canceled":
                    let errorMsg = (json["error"] as? String) ?? "转换失败"
                    completion(.failure(NSError(domain: "RVC", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                case "processing", "starting":
                    progress("处理中...", 0.7)
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) { poll() }
                default:
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) { poll() }
                }
            }.resume()
        }

        poll()
    }
}
