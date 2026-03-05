import Foundation
import Combine

class VoiceRecorderViewModel: ObservableObject {
    @Published var voiceName: String = ""
    @Published var voiceDescription: String = ""
    @Published var minRecordingDuration: TimeInterval = 10
    @Published var recommendedRecordingDuration: TimeInterval = 30
    
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioSamples: [Float] = []
    @Published var recordedFileURL: URL?
    @Published var isTraining: Bool = false
    @Published var trainingProgress: Double = 0
    @Published var statusMessage: String = ""
    @Published var trainedVoiceModel: VoiceModel?
    @Published var errorMessage: String?
    
    private let audioRecorder = AudioRecorder()
    private let rvcService = RVCService()
    private var cancellables = Set<AnyCancellable>()
    
    var canSave: Bool {
        !voiceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && recordedFileURL != nil
    }
    
    var canTrain: Bool {
        canSave && recordingDuration >= minRecordingDuration && !isTraining
    }
    
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var recordingQuality: String {
        if recordingDuration < minRecordingDuration {
            return "录制时间不足 (最少\(Int(minRecordingDuration))秒)"
        } else if recordingDuration < recommendedRecordingDuration {
            return "录制时间较短 (推荐\(Int(recommendedRecordingDuration))秒)"
        } else {
            return "录制质量良好"
        }
    }
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        audioRecorder.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)
        
        audioRecorder.$audioSamples
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioSamples)
        
        audioRecorder.$recordingURL
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordedFileURL)
    }
    
    func startRecording() {
        audioRecorder.requestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.audioRecorder.startRecording()
                self.statusMessage = "正在录制..."
            } else {
                self.errorMessage = "请授予麦克风访问权限"
            }
        }
    }
    
    func stopRecording() {
        recordedFileURL = audioRecorder.stopRecording()
        statusMessage = "录制完成"
    }
    
    func trainVoiceModel(apiKey: String, provider: APIProvider) {
        guard canTrain, let audioURL = recordedFileURL else { return }
        
        isTraining = true
        trainingProgress = 0
        statusMessage = "正在训练声音模型..."
        errorMessage = nil
        
        let name = voiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        rvcService.cloneVoice(
            audioFileURL: audioURL,
            outputName: name,
            apiKey: apiKey,
            provider: provider,
            progress: { status, prog in
                DispatchQueue.main.async {
                    self.statusMessage = status
                    self.trainingProgress = prog
                }
            },
            completion: { result in
                DispatchQueue.main.async {
                    self.isTraining = false
                    
                    switch result {
                    case .success(let modelURL):
                        self.saveVoiceModel(modelURL: modelURL, audioURL: audioURL)
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        )
    }
    
    private func saveVoiceModel(modelURL: URL, audioURL: URL) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let voiceModelsPath = documentsPath.appendingPathComponent("VoiceModels", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: voiceModelsPath.path) {
            try? FileManager.default.createDirectory(at: voiceModelsPath, withIntermediateDirectories: true)
        }
        
        let model = VoiceModel(
            name: voiceName,
            description: voiceDescription,
            sampleFilePath: audioURL,
            modelFilePath: modelURL,
            isTrained: true,
            trainingProgress: 1.0
        )
        
        let modelFileURL = voiceModelsPath.appendingPathComponent("\(model.id.uuidString).json")
        
        if let data = try? JSONEncoder().encode(model) {
            try? data.write(to: modelFileURL)
        }
        
        trainedVoiceModel = model
        statusMessage = "声音模型训练完成!"
        trainingProgress = 1.0
    }
    
    func reset() {
        voiceName = ""
        voiceDescription = ""
        recordingDuration = 0
        audioSamples = []
        recordedFileURL = nil
        trainingProgress = 0
        statusMessage = ""
        trainedVoiceModel = nil
        errorMessage = nil
    }
}
