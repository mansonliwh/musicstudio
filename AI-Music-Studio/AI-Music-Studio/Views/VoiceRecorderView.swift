import SwiftUI

struct VoiceRecorderView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = VoiceRecorderViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                #if os(iOS)
                VStack(alignment: .leading, spacing: 24) {
                    recordingSection
                    voiceModelSection
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                #else
                HStack(alignment: .top, spacing: 24) {
                    recordingSection
                        .frame(maxWidth: .infinity)
                    voiceModelSection
                        .frame(width: 350)
                }
                .padding(.horizontal)
                #endif
            }
            .padding(.vertical)
        }
        .background(Color.appTextBackground)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                Text("声音录入")
                    .font(.system(size: 28, weight: .bold))
            }
            
            Text("录制你的声音，训练专属AI声音模型")
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
    
    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Label("声音信息", systemImage: "person.fill")) {
                VStack(alignment: .leading, spacing: 12) {
                    #if os(iOS)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("声音名称:")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        TextField("例如: 我的声音", text: $viewModel.voiceName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("描述:")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        TextField("可选的描述信息", text: $viewModel.voiceDescription)
                            .textFieldStyle(.roundedBorder)
                    }
                    #else
                    HStack {
                        Text("声音名称:")
                            .frame(width: 80, alignment: .leading)
                        TextField("例如: 我的声音", text: $viewModel.voiceName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("描述:")
                            .frame(width: 80, alignment: .leading)
                        TextField("可选的描述信息", text: $viewModel.voiceDescription)
                            .textFieldStyle(.roundedBorder)
                    }
                    #endif
                }
                .padding()
            }
            
            GroupBox(label: Label("录音", systemImage: "waveform")) {
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appControlBackground)
                            .frame(height: 150)
                        
                        if viewModel.isRecording {
                            WaveformView(samples: viewModel.audioSamples)
                                .frame(height: 100)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("点击下方按钮开始录音")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Text(viewModel.formattedDuration)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                        
                        Spacer()
                        
                        Text(viewModel.recordingQuality)
                            .font(.system(size: 12))
                            .foregroundColor(viewModel.recordingDuration >= viewModel.recommendedRecordingDuration ? .green : .orange)
                    }
                    
                    HStack(spacing: 20) {
                        if viewModel.isRecording {
                            Button(action: {
                                viewModel.stopRecording()
                            }) {
                                HStack {
                                    Image(systemName: "stop.fill")
                                    Text("停止录音")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            Button(action: {
                                viewModel.startRecording()
                            }) {
                                HStack {
                                    Image(systemName: "mic.fill")
                                    Text("开始录音")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                        }
                    }
                }
                .padding()
            }
            
            GroupBox(label: Label("训练声音模型", systemImage: "cpu")) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("训练状态:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(viewModel.statusMessage.isEmpty ? "等待录音" : viewModel.statusMessage)
                                .font(.system(size: 14, weight: .medium))
                        }
                        
                        Spacer()
                        
                        if viewModel.isTraining {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if viewModel.isTraining {
                        ProgressView(value: viewModel.trainingProgress)
                            .progressViewStyle(.linear)
                    }
                    
                    Button(action: {
                        viewModel.trainVoiceModel(apiKey: appState.apiKey, provider: appState.selectedProvider)
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("开始训练")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canTrain || appState.apiKey.isEmpty)
                    
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
                .padding()
            }
        }
    }
    
    private var voiceModelSection: some View {
        GroupBox(label: Label("训练结果", systemImage: "checkmark.seal.fill")) {
            VStack(spacing: 16) {
                if let model = viewModel.trainedVoiceModel {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("训练完成!")
                                .font(.system(size: 16, weight: .bold))
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("名称:")
                                .foregroundColor(.secondary)
                            Text(model.name)
                        }
                        .font(.system(size: 13))
                        
                        if !model.description.isEmpty {
                            HStack {
                                Text("描述:")
                                    .foregroundColor(.secondary)
                                Text(model.description)
                            }
                            .font(.system(size: 13))
                        }
                        
                        HStack {
                            Text("创建时间:")
                                .foregroundColor(.secondary)
                            Text(model.formattedDate)
                        }
                        .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    
                    Text("现在你可以在「AI翻唱」中使用这个声音模型了")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("训练完成的声音模型将在这里显示")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }
}

struct WaveformView: View {
    var samples: [Float]
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let midY = height / 2
            
            guard !samples.isEmpty else { return }
            
            let barWidth = width / CGFloat(samples.count)
            
            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) * barWidth
                let barHeight = CGFloat(sample) * height * 0.8
                
                var path = Path()
                path.move(to: CGPoint(x: x, y: midY - barHeight / 2))
                path.addLine(to: CGPoint(x: x, y: midY + barHeight / 2))
                
                context.stroke(
                    path,
                    with: .color(.accentColor),
                    lineWidth: barWidth * 0.6
                )
            }
        }
    }
}

#Preview {
    VoiceRecorderView()
        .environmentObject(AppState())
}
