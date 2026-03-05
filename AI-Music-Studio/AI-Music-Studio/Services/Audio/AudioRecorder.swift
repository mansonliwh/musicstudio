import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioSamples: [Float] = []
    @Published var recordingURL: URL?
    @Published var averagePower: Float = 0
    
    // macOS properties
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var inputNode: AVAudioInputNode?
    private var audioConverter: AVAudioConverter?
    
    // iOS properties
    #if os(iOS)
    private var avAudioRecorder: AVAudioRecorder?
    #endif
    
    private var recordingStartTime: Date?
    private var timer: Timer?
    private var sampleBuffer: [Float] = []
    
    override init() {
        super.init()
        #if os(macOS)
        setupAudioEngine()
        #endif
    }
    
    #if os(macOS)
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
    }
    #endif
    
    func startRecording() {
        #if os(iOS)
        startRecordingIOS()
        #else
        startRecordingMacOS()
        #endif
    }
    
    #if os(iOS)
    private func startRecordingIOS() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
            recordingURL = audioFilename
            
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            avAudioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            avAudioRecorder?.delegate = self
            avAudioRecorder?.isMeteringEnabled = true
            avAudioRecorder?.record()
            
            isRecording = true
            recordingStartTime = Date()
            startTimer()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    #endif
    
    #if os(macOS)
    private func startRecordingMacOS() {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        recordingURL = audioFilename
        
        do {
            let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
            audioFile = try AVAudioFile(forWriting: audioFilename, settings: recordingFormat.settings)
            
            let inputFormat = inputNode.outputFormat(forBus: 0)
            audioConverter = AVAudioConverter(from: inputFormat, to: recordingFormat)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, let audioFile = self.audioFile, let converter = self.audioConverter else { return }
                
                let inputFrameCount = AVAudioFrameCount(buffer.frameLength)
                let ratio = recordingFormat.sampleRate / inputFormat.sampleRate
                let targetFrameCount = AVAudioFrameCount(Double(inputFrameCount) * ratio)
                
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: targetFrameCount) else { return }
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                
                if let error = error {
                    print("Conversion error: \(error)")
                    return
                }
                
                try? audioFile.write(from: convertedBuffer)
                self.processAudioBuffer(convertedBuffer)
            }
            
            try audioEngine.start()
            isRecording = true
            recordingStartTime = Date()
            startTimer()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    #endif
    
    func stopRecording() -> URL? {
        #if os(iOS)
        avAudioRecorder?.stop()
        avAudioRecorder = nil
        #else
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioFile = nil
        audioConverter = nil
        #endif
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        return recordingURL
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 更新录音时长
            if let startTime = self.recordingStartTime {
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
            
            // iOS: 更新音频电平
            #if os(iOS)
            self.avAudioRecorder?.updateMeters()
            if let power = self.avAudioRecorder?.averagePower(forChannel: 0) {
                let normalizedPower = pow(10, power / 20)
                self.averagePower = normalizedPower
                self.sampleBuffer.append(normalizedPower)
                
                if self.sampleBuffer.count > 100 {
                    let samplesToKeep = 50
                    self.audioSamples = Array(self.sampleBuffer.suffix(samplesToKeep))
                    self.sampleBuffer = Array(self.sampleBuffer.suffix(samplesToKeep))
                }
            }
            #endif
        }
    }
    
    #if os(macOS)
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            sum += sample
            sampleBuffer.append(sample)
        }
        
        let average = sum / Float(frameLength)
        averagePower = average
        
        if sampleBuffer.count > 100 {
            let samplesToKeep = 50
            audioSamples = Array(sampleBuffer.suffix(samplesToKeep))
            sampleBuffer = Array(sampleBuffer.suffix(samplesToKeep))
        }
    }
    #endif
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        #if os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { permission in
                DispatchQueue.main.async {
                    completion(permission)
                }
            }
        default:
            completion(false)
        }
        #else
        AVAudioSession.sharedInstance().requestRecordPermission { permission in
            DispatchQueue.main.async {
                completion(permission)
            }
        }
        #endif
    }
    
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioRecorderDelegate (iOS)
#if os(iOS)
extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio recorder encode error: \(String(describing: error))")
    }
}
#endif
