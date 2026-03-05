import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case songGenerator = "AI写歌"
    case voiceRecorder = "声音录入"
    case voiceCloner = "AI翻唱"
    case musicLibrary = "音乐库"
    #if os(iOS)
    case settings = "设置"
    #endif
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .songGenerator: return "music.note.list"
        case .voiceRecorder: return "mic.fill"
        case .voiceCloner: return "person.wave.2.fill"
        case .musicLibrary: return "music.quarternote.3"
        #if os(iOS)
        case .settings: return "gearshape.fill"
        #endif
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedItem: SidebarItem = .songGenerator
    
    var body: some View {
        #if os(iOS)
        iosTabView
        #else
        macNavigationView
        #endif
    }
    
    // MARK: - iOS TabView
    #if os(iOS)
    @ViewBuilder
    private var iosTabView: some View {
        TabView(selection: $selectedItem) {
            SongGeneratorView()
                .environmentObject(appState)
                .tabItem {
                    Label("AI写歌", systemImage: "music.note.list")
                }
                .tag(SidebarItem.songGenerator)
            
            VoiceRecorderView()
                .environmentObject(appState)
                .tabItem {
                    Label("声音录入", systemImage: "mic.fill")
                }
                .tag(SidebarItem.voiceRecorder)
            
            VoiceClonerView()
                .environmentObject(appState)
                .tabItem {
                    Label("AI翻唱", systemImage: "person.wave.2.fill")
                }
                .tag(SidebarItem.voiceCloner)
            
            MusicLibraryView()
                .environmentObject(appState)
                .tabItem {
                    Label("音乐库", systemImage: "music.quarternote.3")
                }
                .tag(SidebarItem.musicLibrary)
            
            SettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(SidebarItem.settings)
        }
        .tint(.accentColor)
    }
    #endif
    
    // MARK: - macOS Navigation
    #if os(macOS)
    @ViewBuilder
    private var macNavigationView: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItem = item
                    }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.secondary)
                Text("API设置")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Text(appState.selectedProvider.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding()
            .background(Color.appControlBackground)
            .contentShape(Rectangle())
            .onTapGesture {
                if #available(macOS 13.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
        } detail: {
            detailView
        }
        .navigationTitle("AI Music Studio")
        .frame(minWidth: 1000, minHeight: 700)
    }
    #endif
    
    // MARK: - Detail View (macOS only; iOS uses TabView)
    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .songGenerator:
            SongGeneratorView()
        case .voiceRecorder:
            VoiceRecorderView()
        case .voiceCloner:
            VoiceClonerView()
        case .musicLibrary:
            MusicLibraryView()
        #if os(iOS)
        case .settings:
            SettingsView()
        #endif
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
