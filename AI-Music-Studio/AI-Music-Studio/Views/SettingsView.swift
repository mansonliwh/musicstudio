import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var tempAPIKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var saveSuccess: Bool = false

    var body: some View {
        TabView {
            apiSettingsTab
                .tabItem {
                    Label("API设置", systemImage: "key.fill")
                }

            generalSettingsTab
                .tabItem {
                    Label("通用", systemImage: "gearshape.fill")
                }

            aboutTab
                .tabItem {
                    Label("关于", systemImage: "info.circle.fill")
                }
        }
        #if os(macOS)
        .frame(width: 500, height: 400)
        #endif
        .onAppear {
            tempAPIKey = appState.apiKey
        }
    }

    private var apiSettingsTab: some View {
        Form {
            Section {
                HStack {
                    if showAPIKey {
                        TextField("Replicate API Key", text: $tempAPIKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Replicate API Key", text: $tempAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: {
                        showAPIKey.toggle()
                    }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                HStack {
                    Spacer()

                    Button("保存") {
                        appState.saveAPIKey(tempAPIKey)
                        saveSuccess = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            saveSuccess = false
                        }
                    }
                    .disabled(tempAPIKey.isEmpty)

                    if saveSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            } header: {
                Text("Replicate API密钥")
            } footer: {
                Text("API密钥将安全存储在系统钥匙串中。所有AI功能均通过 Replicate 提供。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("获取API密钥:")
                        .font(.system(size: 13, weight: .medium))

                    Link("Replicate官网", destination: URL(string: "https://replicate.com")!)
                }
            } header: {
                Text("资源链接")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var generalSettingsTab: some View {
        Form {
            Section {
                Toggle("自动保存生成结果", isOn: .constant(true))
                Toggle("生成完成后播放预览", isOn: .constant(true))
            } header: {
                Text("生成设置")
            }

            Section {
                Toggle("检查更新", isOn: .constant(true))
                Toggle("发送匿名使用统计", isOn: .constant(false))
            } header: {
                Text("其他设置")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("AI Music Studio")
                .font(.system(size: 24, weight: .bold))

            Text("版本 1.0.0")
                .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 12) {
                Text("一款强大的AI音乐创作工具")
                    .font(.system(size: 14))

                Text("支持AI写歌、声音克隆、AI翻唱等功能")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 8) {
                Text("技术栈")
                    .font(.system(size: 12, weight: .medium))

                HStack(spacing: 16) {
                    Label("MiniMax Music", systemImage: "music.note")
                    Label("RVC", systemImage: "person.wave.2")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Text("Copyright 2024. All rights reserved.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
