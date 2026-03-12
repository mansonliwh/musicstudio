import Foundation
import Combine

class VoiceClonerViewModel: ObservableObject {
    @Published var selectedVoiceModel: VoiceModel?
    @Published var sourceAudioURL: URL?
    @Published var selectedPitch: RVCService.RVCPitch = .normal
    @Published var outputName: String = ""
    
    @Published var isConverting: Bool = false
    @Published var progress: Double = 0
    @Published var statusMessage: String = ""
    @Published var convertedAudioURL: URL?
    @Published var errorMessage: String?
    
    @Published var voiceModels: [VoiceModel] = []
    
    private let rvcService = RVCService()
    private var cancellables = Set<AnyCancellable>()
    
    var canConvert: Bool {
        selectedVoiceModel != nil && sourceAudioURL != nil && !isConverting
    }
    
    func convertVoice(apiKey: String) {
        guard canConvert,
              let voiceModel = selectedVoiceModel,
              let sourceURL = sourceAudioURL else { return }

        isConverting = true
        progress = 0
        statusMessage = "正在准备声音转换..."
        errorMessage = nil

        rvcService.convertVoice(
            sourceAudioURL: sourceURL,
            voiceModel: voiceModel,
            pitch: selectedPitch,
            apiKey: apiKey,
            progress: { status, prog in
                DispatchQueue.main.async {
                    self.statusMessage = status
                    self.progress = prog
                }
            },
            completion: { result in
                DispatchQueue.main.async {
                    self.isConverting = false
                    
                    switch result {
                    case .success(let audioURL):
                        self.downloadConvertedAudio(audioURL: audioURL)
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        )
    }
    
    private func downloadConvertedAudio(audioURL: URL) {
        statusMessage = "正在下载转换后的音频..."
        progress = 0.9
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let convertedPath = documentsPath.appendingPathComponent("Converted", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: convertedPath.path) {
            try? FileManager.default.createDirectory(at: convertedPath, withIntermediateDirectories: true)
        }
        
        let filename = "converted_\(Date().timeIntervalSince1970).wav"
        let destinationURL = convertedPath.appendingPathComponent(filename)
        
        URLSession.shared.downloadTask(with: audioURL) { localURL, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "下载失败: \(error.localizedDescription)"
                    self.progress = 0
                }
                return
            }
            
            guard let localURL = localURL else { return }
            
            do {
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                
                DispatchQueue.main.async {
                    self.convertedAudioURL = destinationURL
                    self.statusMessage = "转换完成!"
                    self.progress = 1.0
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "保存失败: \(error.localizedDescription)"
                    self.progress = 0
                }
            }
        }.resume()
    }
    
    func selectSourceAudio(from url: URL) {
        sourceAudioURL = url
    }
    
    func reset() {
        sourceAudioURL = nil
        convertedAudioURL = nil
        progress = 0
        statusMessage = ""
        errorMessage = nil
    }
    
    func loadVoiceModels() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let voiceModelsPath = documentsPath.appendingPathComponent("VoiceModels", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: voiceModelsPath.path) else {
            voiceModels = []
            return
        }
        
        var loadedModels: [VoiceModel] = []
        
        if let enumerator = FileManager.default.enumerator(at: voiceModelsPath, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "json" {
                    if let data = try? Data(contentsOf: fileURL),
                       let model = try? JSONDecoder().decode(VoiceModel.self, from: data) {
                        loadedModels.append(model)
                    }
                }
            }
        }
        
        voiceModels = loadedModels.sorted { $0.createdAt > $1.createdAt }
    }
    
    func saveVoiceModel(_ model: VoiceModel) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let voiceModelsPath = documentsPath.appendingPathComponent("VoiceModels", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: voiceModelsPath.path) {
            try? FileManager.default.createDirectory(at: voiceModelsPath, withIntermediateDirectories: true)
        }
        
        let modelFileURL = voiceModelsPath.appendingPathComponent("\(model.id.uuidString).json")
        
        if let data = try? JSONEncoder().encode(model) {
            try? data.write(to: modelFileURL)
        }
        
        loadVoiceModels()
    }
}
