import SwiftUI

struct SongGeneratorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SongGeneratorViewModel()
    @StateObject private var audioPlayer = AudioPlayer()
    #if os(iOS)
    @State private var shareItem: ShareableFile?
    #endif
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                #if os(iOS)
                VStack(alignment: .leading, spacing: 24) {
                    inputSection
                    previewSection
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                #else
                HStack(alignment: .top, spacing: 24) {
                    inputSection
                        .frame(maxWidth: .infinity)
                    previewSection
                        .frame(width: 350)
                }
                .padding(.horizontal)
                #endif
                
                if viewModel.isGenerating {
                    progressSection
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.appTextBackground)
        #if os(iOS)
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url) { shareItem = nil }
        }
        #endif
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "music.note.list")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                Text("AI写歌")
                    .font(.system(size: 28, weight: .bold))
            }
            
            Text("输入描述，让AI为你创作独一无二的音乐")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Label("音乐描述", systemImage: "text.quote")) {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $viewModel.prompt)
                        .frame(height: 100)
                        .font(.system(size: 14))
                        .padding(8)
                        .background(Color.appControlBackground)
                        .cornerRadius(8)
                    
                    Text("描述你想要的音乐风格、情绪、歌词或任何想法")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            #if os(iOS)
            // iOS: 简化布局,使用单列形式
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("风格", systemImage: "guitars.fill")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Picker("", selection: $viewModel.genre) {
                        Text("选择风格").tag("")
                        ForEach(viewModel.genres, id: \.self) { genre in
                            Text(genre).tag(genre)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Label("情绪", systemImage: "face.smiling")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Picker("", selection: $viewModel.mood) {
                        Text("选择情绪").tag("")
                        ForEach(viewModel.moods, id: \.self) { mood in
                            Text(mood).tag(mood)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding()
            .background(Color.appControlBackground)
            .cornerRadius(12)
            #else
            // macOS: 保持原有的并排布局
            HStack(spacing: 16) {
                GroupBox(label: Label("风格", systemImage: "guitars.fill")) {
                    Picker("", selection: $viewModel.genre) {
                        Text("选择风格").tag("")
                        ForEach(viewModel.genres, id: \.self) { genre in
                            Text(genre).tag(genre)
                        }
                    }
                    .frame(width: 150)
                }
                
                GroupBox(label: Label("情绪", systemImage: "face.smiling")) {
                    Picker("", selection: $viewModel.mood) {
                        Text("选择情绪").tag("")
                        ForEach(viewModel.moods, id: \.self) { mood in
                            Text(mood).tag(mood)
                        }
                    }
                    .frame(width: 150)
                }
            }
            #endif
            
            #if os(iOS)
            // iOS: 简化布局,使用单列形式
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("BPM", systemImage: "metronome")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(viewModel.bpm) BPM")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: Binding(
                        get: { Double(viewModel.bpm) },
                        set: { viewModel.bpm = Int($0) }
                    ), in: 60...200)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("时长", systemImage: "clock.fill")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(viewModel.duration) 秒")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: Binding(
                        get: { Double(viewModel.duration) },
                        set: { viewModel.duration = Int($0) }
                    ), in: 10...120)
                }
            }
            .padding()
            .background(Color.appControlBackground)
            .cornerRadius(12)
            #else
            // macOS: 保持原有的并排布局
            HStack(spacing: 16) {
                GroupBox(label: Label("BPM", systemImage: "metronome")) {
                    VStack(alignment: .leading) {
                        Slider(value: Binding(
                            get: { Double(viewModel.bpm) },
                            set: { viewModel.bpm = Int($0) }
                        ), in: 60...200)
                        Text("\(viewModel.bpm) BPM")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(width: 150)
                    .padding(.vertical, 4)
                }
                
                GroupBox(label: Label("时长", systemImage: "clock.fill")) {
                    VStack(alignment: .leading) {
                        Slider(value: Binding(
                            get: { Double(viewModel.duration) },
                            set: { viewModel.duration = Int($0) }
                        ), in: 10...120)
                        Text("\(viewModel.duration) 秒")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(width: 150)
                    .padding(.vertical, 4)
                }
            }
            #endif
            
            GroupBox(label: Label("生成选项", systemImage: "slider.horizontal.3")) {
                VStack(alignment: .leading, spacing: 12) {
                    // 模式选择
                    Toggle(isOn: $viewModel.useCustomLyrics) {
                        Label("自定义歌词模式", systemImage: "doc.text")
                    }

                    if viewModel.useCustomLyrics {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("歌曲标题")
                                .font(.system(size: 12, weight: .medium))
                            TextField("输入歌曲标题", text: $viewModel.customTitle)
                                .textFieldStyle(.roundedBorder)

                            Text("歌词")
                                .font(.system(size: 12, weight: .medium))
                            TextEditor(text: $viewModel.customLyrics)
                                .frame(height: 120)
                                .font(.system(size: 13))
                                .padding(4)
                                .background(Color.appControlBackground)
                                .cornerRadius(6)
                        }
                        .padding(.top, 8)
                    }

                    Divider()

                    // 纯音乐选项
                    Toggle(isOn: $viewModel.instrumental) {
                        Label("纯音乐 (无歌词)", systemImage: "music.note")
                    }
                }
                .padding()
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.generateSong(apiKey: appState.apiKey)
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("生成音乐")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canGenerate || appState.apiKey.isEmpty)
                
                Button(action: {
                    viewModel.reset()
                }) {
                    Text("重置")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
            }
            
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var previewSection: some View {
        GroupBox(label: Label("预览", systemImage: "play.circle.fill")) {
            VStack(spacing: 16) {
                if let song = viewModel.generatedSong {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(song.title)
                            .font(.system(size: 14, weight: .medium))
                        
                        if let genre = song.genre {
                            HStack {
                                Text("风格:").foregroundColor(.secondary)
                                Text(genre)
                            }
                            .font(.system(size: 12))
                        }
                        
                        HStack {
                            Text("时长:").foregroundColor(.secondary)
                            Text(song.formattedDuration)
                        }
                        .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                    
                    if let audioURL = song.filePath {
                        AudioPlayerView(audioPlayer: audioPlayer, audioURL: audioURL)
                        
                        Button(action: {
                            exportSong(song)
                        }) {
                            Label("导出MP3", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("生成的音乐将在这里显示")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }
    
    private var progressSection: some View {
        GroupBox(label: Label("生成进度", systemImage: "progress.indicator")) {
            VStack(spacing: 12) {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                
                Text(viewModel.statusMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    private func exportSong(_ song: Song) {
        guard let sourceURL = song.filePath else { return }
        let fileName = "\(song.title).mp3"
        ExportHelper.exportAudio(sourceURL: sourceURL, suggestedFileName: fileName) { result in
            switch result {
            case .success(let url):
                #if os(iOS)
                shareItem = ShareableFile(url: url)
                #endif
                break
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
}

#Preview {
    SongGeneratorView()
        .environmentObject(AppState())
}
