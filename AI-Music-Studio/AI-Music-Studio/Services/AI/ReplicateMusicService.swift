import Foundation
import Combine

struct ReplicateSongData {
    let title: String?
    let audioUrl: String?
    let duration: Double?
}

class ReplicateMusicService {
    static let shared = ReplicateMusicService()

    private init() {}

    private let submitURL = URL(string: "https://api.replicate.com/v1/models/minimax/music-1.5/predictions")!

    // MARK: - 灵感模式生成
    func generateWithInspiration(
        prompt: String,
        apiKey: String,
        instrumental: Bool = false,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<[ReplicateSongData], Error>) -> Void
    ) {
        // minimax/music-1.5 要求 lyrics 字段是必需的（10-600 字符）
        // 对于灵感模式，我们使用一个默认的歌词结构
        let defaultLyrics = instrumental ? "[Instrumental]" : """
        [intro]
        [verse]
        音乐响起，旋律流淌
        心中的故事，随歌声飞扬
        [chorus]
        这一刻，让音乐说话
        让情感自由绽放
        [bridge]
        每一个音符都是心声
        每一段旋律都是梦想
        [outro]
        """

        var input: [String: Any] = [
            "lyrics": defaultLyrics,
            "prompt": prompt
        ]
        if instrumental {
            input["prompt"] = "[Instrumental] \(prompt)"
        }

        submitPrediction(input: input, apiKey: apiKey, progress: progress, completion: completion)
    }

    // MARK: - 自定义模式生成
    func generateWithCustom(
        title: String,
        lyrics: String,
        tags: String,
        apiKey: String,
        instrumental: Bool = false,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<[ReplicateSongData], Error>) -> Void
    ) {
        // minimax/music-1.5 要求 lyrics 字段最少 10 个字符
        // 如果歌词太短，补充默认内容
        var finalLyrics = lyrics
        if lyrics.count < 10 {
            finalLyrics = lyrics + "\n" + """
            [verse]
            音乐流淌，故事飞扬
            [chorus]
            让歌声传递心声
            """
        }

        var input: [String: Any] = [
            "lyrics": finalLyrics
        ]
        if !tags.isEmpty {
            input["prompt"] = tags
        }
        if instrumental {
            input["prompt"] = "[Instrumental] \(tags)"
        }

        submitPrediction(input: input, apiKey: apiKey, progress: progress, completion: completion)
    }

    // MARK: - 下载音频文件
    func downloadAudio(from url: URL, to destination: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        URLSession.shared.downloadTask(with: url) { localURL, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let localURL = localURL else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Music", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                }
                return
            }

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: localURL, to: destination)
                DispatchQueue.main.async { completion(.success(destination)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    // MARK: - Private

    private func submitPrediction(
        input: [String: Any],
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<[ReplicateSongData], Error>) -> Void
    ) {
        let body: [String: Any] = ["input": input]

        var request = URLRequest(url: submitURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        progress("正在提交生成任务...", 0.1)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                print("[Music] Submit Response: \(responseBody)")
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Music", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析响应"])))
                }
                return
            }

            if let errorMsg = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Music", code: -1, userInfo: [NSLocalizedDescriptionKey: "API 错误: \(errorMsg)"])))
                }
                return
            }

            guard let predictionId = json["id"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Music", code: -1, userInfo: [NSLocalizedDescriptionKey: "创建预测失败: \(json)"])))
                }
                return
            }

            progress("任务已提交，等待生成...", 0.2)

            self.pollResult(predictionId: predictionId, apiKey: apiKey, progress: progress, completion: completion)
        }.resume()
    }

    private func pollResult(
        predictionId: String,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<[ReplicateSongData], Error>) -> Void
    ) {
        let url = URL(string: "https://api.replicate.com/v1/predictions/\(predictionId)")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        func poll() {
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }

                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("[Music] Poll Response: \(responseBody)")
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "Music", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析轮询响应"])))
                    }
                    return
                }

                guard let status = json["status"] as? String else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "Music", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应缺少状态"])))
                    }
                    return
                }

                switch status {
                case "succeeded":
                    // minimax/music-1.5 output is an audio file URL string
                    if let output = json["output"] as? String,
                       let _ = URL(string: output) {
                        let songData = ReplicateSongData(
                            title: nil,
                            audioUrl: output,
                            duration: nil
                        )
                        progress("生成完成!", 1.0)
                        DispatchQueue.main.async {
                            completion(.success([songData]))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "Music", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效音频URL"])))
                        }
                    }
                case "failed", "canceled":
                    let errorMsg = (json["error"] as? String) ?? "生成失败"
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "Music", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    }
                case "processing", "starting":
                    progress("正在生成音乐...", 0.5)
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) { poll() }
                default:
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) { poll() }
                }
            }.resume()
        }

        poll()
    }
}
