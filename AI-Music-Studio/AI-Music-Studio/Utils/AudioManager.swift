import Foundation
import AVFoundation

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentSong: Song?
    
    private var audioPlayer: AVAudioPlayer?
    
    private override init() {
        super.init()
    }
    
    func play(song: Song) {
        guard let filePath = song.filePath else { return }
        play(url: filePath)
        currentSong = song
    }
    
    func play(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.delegate = self
            duration = audioPlayer?.duration ?? 0
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        currentSong = nil
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    func setVolume(_ volume: Float) {
        audioPlayer?.volume = volume
    }
    
    func updateCurrentTime() {
        currentTime = audioPlayer?.currentTime ?? 0
    }
    
    var formattedCurrentTime: String {
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        currentSong = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
    }
}
