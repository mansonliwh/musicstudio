import SwiftUI

struct VoiceClonerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = VoiceClonerViewModel()
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var showFileImporter = false
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
                    outputSection
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                #else
                HStack(alignment: .top, spacing: 24) {
                    inputSection
                        .frame(maxWidth: .infinity)
                    outputSection
                        .frame(width: 350)
                }
                .padding(.horizontal)
                #endif
                
                if viewModel.isConverting {
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
        .onAppear {
            viewModel.loadVoiceModels()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                Text("AI翻唱")
                    .font(.system(size: 28, weight: .bold))
            }
            
            Text("使用你的AI声音模型进行翻唱")
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
            GroupBox(label: Label("选择声音模型", systemImage: "person.crop.circle.fill")) {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.voiceModels.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("暂无声音模型")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("请先在「声音录入」中训练你的声音模型")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        Picker("", selection: $viewModel.selectedVoiceModel) {
                            Text("选择声音模型").tag(nil as VoiceModel?)
                            ForEach(viewModel.voiceModels) { model in
                                HStack {
                                    Text(model.name)
                                    if model.isTrained {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .tag(model as VoiceModel?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            
            GroupBox(label: Label("选择源音频", systemImage: "music.note")) {
                VStack(spacing: 12) {
                    if let sourceURL = viewModel.sourceAudioURL {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("已选择文件:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text(sourceURL.lastPathComponent)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            Spacer()
                            Button(action: {
                                viewModel.sourceAudioURL = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        Button(action: {
                            showFileImporter = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.accentColor)
                                Text("点击选择音频文件")
                                    .font(.system(size: 14))
                                Text("支持 WAV, MP3, M4A 格式")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.plain)
                        .background(Color.appControlBackground)
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            GroupBox(label: Label("转换设置", systemImage: "slider.horizontal.3")) {
                VStack(alignment: .leading, spacing: 16) {
                    #if os(iOS)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("音调调整:")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $viewModel.selectedPitch) {
                            ForEach([RVCService.RVCPitch.veryLow, .low, .normal, .high, .veryHigh], id: \.self) { pitch in
                                Text(pitchText(pitch)).tag(pitch)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    #else
                    HStack {
                        Text("音调调整:")
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("", selection: $viewModel.selectedPitch) {
                            ForEach([RVCService.RVCPitch.veryLow, .low, .normal, .high, .veryHigh], id: \.self) { pitch in
                                Text(pitchText(pitch)).tag(pitch)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    }
                    #endif
                }
                .padding()
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.convertVoice(apiKey: appState.apiKey, provider: appState.selectedProvider)
                }) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                        Text("开始转换")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canConvert || appState.apiKey.isEmpty)
                
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
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .mp3, .wav, .aiff],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.selectSourceAudio(from: url)
                }
            case .failure(let error):
                print("File import error: \(error)")
            }
        }
    }
    
    private var outputSection: some View {
        GroupBox(label: Label("输出预览", systemImage: "play.circle.fill")) {
            VStack(spacing: 16) {
                if let outputURL = viewModel.convertedAudioURL {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("转换完成!")
                                .font(.system(size: 16, weight: .bold))
                        }
                        
                        Divider()
                        
                        Text("输出文件:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(outputURL.lastPathComponent)
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    
                    AudioPlayerView(audioPlayer: audioPlayer, audioURL: outputURL)
                    
                    Button(action: {
                        exportAudio(outputURL)
                    }) {
                        Label("导出MP3", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("转换后的音频将在这里显示")
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
        GroupBox(label: Label("转换进度", systemImage: "progress.indicator")) {
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
    
    private func pitchText(_ pitch: RVCService.RVCPitch) -> String {
        switch pitch {
        case .veryLow: return "极低"
        case .low: return "低"
        case .normal: return "正常"
        case .high: return "高"
        case .veryHigh: return "极高"
        }
    }
    
    private func exportAudio(_ url: URL) {
        ExportHelper.exportAudio(sourceURL: url, suggestedFileName: "converted_audio.mp3") { result in
            switch result {
            case .success(let exportedURL):
                #if os(iOS)
                shareItem = ShareableFile(url: exportedURL)
                #endif
                break
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
}

#Preview {
    VoiceClonerView()
        .environmentObject(AppState())
}
