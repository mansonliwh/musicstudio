import Foundation
import Combine

// Suno API 响应模型
struct SunoTaskResponse: Codable {
    let code: Int?
    let data: SunoTaskData?
    let message: String?
}

struct SunoTaskData: Codable {
    let taskId: String?
    let status: String?
    let data: [SunoSongData]?
}

struct SunoSongData: Codable {
    let id: String?
    let title: String?
    let audioUrl: String?
    let imageUrl: String?
    let createTime: Double?
    let status: String?
    let modelName: String?
    let tags: String?
    let duration: Double?
}

class SunoService {
    static let shared = SunoService()

    private init() {}

    // MARK: - Suno API Endpoints (via UniAPI)
    private var submitURL: URL {
        URL(string: "https://api.uniapi.io/suno/submit/music")!
    }

    private var fetchBaseURL: URL {
        URL(string: "https://api.uniapi.io/suno/fetch")!
    }

    // MARK: - 灵感模式生成
    func generateWithInspiration(
        prompt: String,
        apiKey: String,
        instrumental: Bool = false,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<[SunoSongData], Error>) -> Void
    ) {
        let body: [String: Any] = [
            "gpt_description_prompt": prompt,
            "mv": "chirp-v4",
            "instrumental": instrumental
        ]

        submitTask(url: submitURL, body: body, apiKey: apiKey, progress: progress, completion: completion)
    }

    // MARK: - 自定义模式生成
    func generateWithCustom(
        title: String,
        lyrics: String,
        tags: String,
        apiKey: String,
        instrumental: Bool = false,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<[SunoSongData], Error>) -> Void
    ) {
        let body: [String: Any] = [
            "title": title,
            "lyrics": lyrics,
            "tags": tags,
            "mv": "chirp-v4",
            "instrumental": instrumental
        ]

        submitTask(url: submitURL, body: body, apiKey: apiKey, progress: progress, completion: completion)
    }

    // MARK: - 提交任务
    private func submitTask(
        url: URL,
        body: [String: Any],
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<[SunoSongData], Error>) -> Void
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        progress("正在提交生成任务...", 0.1)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                print("[Suno] Submit Response: \(responseBody)")
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Suno", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析响应"])))
                }
                return
            }

            // 检查错误 - UniAPI 返回 code: "success" 或错误信息
            let code = json["code"] as? String
            if code != "success" {
                let errorMsg = json["message"] as? String ?? "未知错误"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Suno", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                }
                return
            }

            // 获取 taskId
            guard let dataObj = json["data"] as? [String: Any],
                  let taskId = dataObj["taskId"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Suno", code: -1, userInfo: [NSLocalizedDescriptionKey: "未能获取任务ID: \(json)"])))
                }
                return
            }

            progress("任务已提交，等待生成...", 0.2)

            // 开始轮询
            self.pollTaskStatus(
                taskId: taskId,
                apiKey: apiKey,
                progress: progress,
                completion: completion
            )
        }.resume()
    }

    // MARK: - 轮询任务状态
    private func pollTaskStatus(
        taskId: String,
        apiKey: String,
        progress: @escaping (String, Double) -> Void,
        completion: @escaping (Result<[SunoSongData], Error>) -> Void
    ) {
        // UniAPI Suno fetch 端点需要 POST + 数组格式的 ids
        let url = fetchBaseURL
        let body: [String: Any] = ["ids": [taskId]]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        func poll() {
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }

                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("[Suno] Poll Response: \(responseBody)")
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "Suno", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析轮询响应"])))
                    }
                    return
                }

                // 检查错误 - UniAPI 返回 code: "success" 或错误信息
                let code = json["code"] as? String
                if code != "success" {
                    let errorMsg = json["message"] as? String ?? "未知错误"
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "Suno", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    }
                    return
                }

                // UniAPI fetch 返回 data 是数组格式: [{"task_id": "...", "data": [songs]}]
                guard let taskList = json["data"] as? [[String: Any]],
                      let firstTask = taskList.first,
                      let songs = firstTask["data"] as? [[String: Any]] else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "Suno", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应格式错误: \(json)"])))
                    }
                    return
                }

                // 检查任务状态 - UniAPI 返回 SUCCESS, PROCESSING, FAILED 等
                let taskStatus = firstTask["status"] as? String ?? ""

                if taskStatus == "FAILED" {
                    let failReason = firstTask["fail_reason"] as? String ?? "生成失败"
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "Suno", code: -1, userInfo: [NSLocalizedDescriptionKey: failReason])))
                    }
                    return
                }

                if taskStatus == "PROCESSING" || taskStatus == "PENDING" || songs.isEmpty {
                    progress("正在生成音乐...", 0.5)
                    // 继续轮询
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                        poll()
                    }
                    return
                }

                // 检查歌曲状态 - Suno 使用 "state" 或 "status" 字段
                var allCompleted = true
                var progressValue = 0.7

                for song in songs {
                    let state = song["state"] as? String ?? song["status"] as? String ?? ""
                    // Suno 状态: submitted, queued, streaming, succeeded, failed, error
                    // 或者: pending, processing, complete
                    if state != "succeeded" && state != "complete" && state != "completed" {
                        allCompleted = false
                        progressValue = min(progressValue + 0.05, 0.9)
                        break
                    }
                }

                if allCompleted {
                    // 解析歌曲数据 - UniAPI 返回 snake_case 字段名
                    let songDataList = songs.compactMap { songDict -> SunoSongData? in
                        guard let audioUrl = songDict["audio_url"] as? String else { return nil }

                        return SunoSongData(
                            id: songDict["id"] as? String,
                            title: songDict["title"] as? String,
                            audioUrl: audioUrl,
                            imageUrl: songDict["image_url"] as? String,
                            createTime: songDict["created_at"] as? Double,
                            status: songDict["status"] as? String ?? songDict["state"] as? String,
                            modelName: songDict["model_name"] as? String,
                            tags: songDict["tags"] as? String,
                            duration: songDict["duration"] as? Double
                        )
                    }

                    progress("生成完成!", 1.0)
                    DispatchQueue.main.async {
                        completion(.success(songDataList))
                    }
                } else {
                    progress("正在生成音乐...", progressValue)
                    // 继续轮询
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                        poll()
                    }
                }
            }.resume()
        }

        poll()
    }

    // MARK: - 下载音频文件
    func downloadAudio(from url: URL, to destination: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        URLSession.shared.downloadTask(with: url) { localURL, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let localURL = localURL else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Suno", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                }
                return
            }

            do {
                // 如果目标文件已存在，先删除
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: localURL, to: destination)
                DispatchQueue.main.async {
                    completion(.success(destination))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
