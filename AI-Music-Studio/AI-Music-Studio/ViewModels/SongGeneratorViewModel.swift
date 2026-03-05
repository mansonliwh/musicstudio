import Foundation
import Combine

class SongGeneratorViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var genre: String = ""
    @Published var mood: String = ""
    @Published var bpm: Int = 120
    @Published var duration: Int = 30
    @Published var selectedModel: MusicGenModel = .medium

    // Suno 新增选项
    @Published var useCustomLyrics: Bool = false
    @Published var customLyrics: String = ""
    @Published var customTitle: String = ""
    @Published var instrumental: Bool = false

    @Published var isGenerating: Bool = false
    @Published var progress: Double = 0
    @Published var statusMessage: String = ""
    @Published var generatedSong: Song?
    @Published var errorMessage: String?

    let genres = ["流行", "摇滚", "电子", "爵士", "古典", "民谣", "嘻哈", "R&B", "乡村", "金属"]
    let moods = ["快乐", "悲伤", "激昂", "平静", "浪漫", "忧郁", "活力", "神秘", "温暖", "紧张"]

    private let sunoService = SunoService.shared
    private var cancellables = Set<AnyCancellable>()

    var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    func generateSong(apiKey: String, provider: APIProvider) {
        guard canGenerate else { return }

        isGenerating = true
        progress = 0
        statusMessage = "正在准备生成..."
        errorMessage = nil

        let tags = buildTags()

        if useCustomLyrics && !customLyrics.isEmpty {
            // 自定义模式：使用自定义歌词
            let title = customTitle.isEmpty ? "我的歌曲" : customTitle
            sunoService.generateWithCustom(
                title: title,
                lyrics: customLyrics,
                tags: tags,
                apiKey: apiKey,
                instrumental: instrumental,
                progress: { status, prog in
                    DispatchQueue.main.async {
                        self.statusMessage = status
                        self.progress = prog
                    }
                },
                completion: { result in
                    self.handleSunoResult(result, apiKey: apiKey)
                }
            )
        } else {
            // 灵感模式：AI 自动生成歌词和旋律
            let fullPrompt = buildFullPrompt()
            sunoService.generateWithInspiration(
                prompt: fullPrompt,
                apiKey: apiKey,
                instrumental: instrumental,
                progress: { status, prog in
                    DispatchQueue.main.async {
                        self.statusMessage = status
                        self.progress = prog
                    }
                },
                completion: { result in
                    self.handleSunoResult(result, apiKey: apiKey)
                }
            )
        }
    }

    private func handleSunoResult(_ result: Result<[SunoSongData], Error>, apiKey: String) {
        DispatchQueue.main.async {
            self.isGenerating = false

            switch result {
            case .success(let songs):
                if let firstSong = songs.first, let audioUrlString = firstSong.audioUrl,
                   let audioURL = URL(string: audioUrlString) {
                    self.downloadAndSaveSong(audioURL: audioURL, songData: firstSong)
                } else {
                    self.errorMessage = "未能获取音频文件"
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func buildTags() -> String {
        var tags: [String] = []
        if !genre.isEmpty {
            tags.append(genre)
        }
        if !mood.isEmpty {
            tags.append(mood)
        }
        // 添加中文标签帮助 Suno 生成中文歌曲
        if tags.isEmpty {
            tags.append("中文流行")
        }
        return tags.joined(separator: " ")
    }
    
    private func buildFullPrompt() -> String {
        var parts: [String] = []
        
        if !genre.isEmpty {
            parts.append(genre)
        }
        if !mood.isEmpty {
            parts.append(mood)
        }
        parts.append(prompt)
        
        return parts.joined(separator: ", ")
    }
    
    private func downloadAndSaveSong(audioURL: URL, songData: SunoSongData? = nil) {
        statusMessage = "正在下载音频..."
        progress = 0.9

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let songsPath = documentsPath.appendingPathComponent("Songs", isDirectory: true)

        if !FileManager.default.fileExists(atPath: songsPath.path) {
            try? FileManager.default.createDirectory(at: songsPath, withIntermediateDirectories: true)
        }

        // Suno 返回的是 mp3 格式
        let songFilename = "song_\(Date().timeIntervalSince1970).mp3"
        let destinationURL = songsPath.appendingPathComponent(songFilename)

        sunoService.downloadAudio(from: audioURL, to: destinationURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedURL):
                    let title = songData?.title ?? self.generateTitle()
                    let songDuration = songData?.duration ?? Double(self.duration)

                    let song = Song(
                        title: title,
                        prompt: self.prompt,
                        duration: songDuration,
                        filePath: savedURL,
                        genre: self.genre.isEmpty ? nil : self.genre,
                        mood: self.mood.isEmpty ? nil : self.mood,
                        bpm: self.bpm
                    )

                    self.generatedSong = song
                    self.statusMessage = "生成完成!"
                    self.progress = 1.0

                case .failure(let error):
                    self.errorMessage = "下载失败: \(error.localizedDescription)"
                    self.progress = 0
                }
            }
        }
    }
    
    private func generateTitle() -> String {
        if !genre.isEmpty {
            return "\(genre)音乐 - \(Date().formatted(date: .abbreviated, time: .shortened))"
        }
        return "AI生成音乐 - \(Date().formatted(date: .abbreviated, time: .shortened))"
    }
    
    func reset() {
        prompt = ""
        genre = ""
        mood = ""
        progress = 0
        statusMessage = ""
        errorMessage = nil
        generatedSong = nil
        useCustomLyrics = false
        customLyrics = ""
        customTitle = ""
        instrumental = false
    }
}
