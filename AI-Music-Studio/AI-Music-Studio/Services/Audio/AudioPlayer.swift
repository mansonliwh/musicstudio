import Foundation
import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var url: URL?
    
    override init() {
        super.init()
    }
    
    func load(url: URL) {
        self.url = url
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session for playback: \(error)")
        }
        #endif
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("Failed to load audio: \(error)")
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimer()
    }
    
    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }
    
    func seekForward(_ seconds: TimeInterval = 10) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func seekBackward(_ seconds: TimeInterval = 10) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    func setVolume(_ value: Float) {
        volume = value
        player?.volume = value
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentTime() {
        currentTime = player?.currentTime ?? 0
    }
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    var formattedDuration: String {
        formatTime(duration)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func cleanup() {
        stop()
        player = nil
        url = nil
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        stopTimer()
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown")")
    }
}
