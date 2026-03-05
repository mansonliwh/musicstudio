import SwiftUI

struct AudioPlayerView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    let audioURL: URL
    var compact: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.load(url: audioURL)
                        audioPlayer.play()
                    }
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: compact ? 16 : 20))
                        .foregroundColor(.white)
                        .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)
                        .background(Color.accentColor)
                        .cornerRadius(compact ? 16 : 20)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Slider(
                        value: Binding(
                            get: { audioPlayer.currentTime },
                            set: { audioPlayer.seek(to: $0) }
                        ),
                        in: 0...max(audioPlayer.duration, 1)
                    ) {
                        Text("进度")
                    }
                    
                    HStack {
                        Text(audioPlayer.formattedCurrentTime)
                        Spacer()
                        Text(audioPlayer.formattedDuration)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                
                if !compact {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 10))
                        
                        Slider(
                            value: $audioPlayer.volume,
                            in: 0...1
                        )
                        .frame(width: 60)
                    }
                }
            }
        }
        .onAppear {
            audioPlayer.load(url: audioURL)
        }
        .onDisappear {
            audioPlayer.cleanup()
        }
    }
}

#Preview {
    AudioPlayerView(
        audioPlayer: AudioPlayer(),
        audioURL: URL(fileURLWithPath: "/path/to/audio.wav")
    )
    .padding()
    .frame(width: 400)
}
