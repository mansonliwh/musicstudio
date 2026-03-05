import SwiftUI

@main
struct AI_Music_StudioApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                #if os(macOS)
                .frame(minWidth: 1000, minHeight: 700)
                #endif
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        #endif
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        #endif
    }
}

class AppState: ObservableObject {
    @Published var apiKey: String = ""
    @Published var selectedProvider: APIProvider = .replicate
    @Published var voiceModels: [VoiceModel] = []
    @Published var songs: [Song] = []
    
    init() {
        loadSavedData()
    }
    
    func loadSavedData() {
        if let savedKey = KeychainHelper.shared.load(key: "apiKey") {
            apiKey = savedKey
        }
        if let providerRaw = UserDefaults.standard.string(forKey: "selectedProvider"),
           let provider = APIProvider(rawValue: providerRaw) {
            selectedProvider = provider
        }
    }
    
    func saveAPIKey(_ key: String) {
        apiKey = key
        KeychainHelper.shared.save(key: "apiKey", value: key)
    }
}

enum APIProvider: String, CaseIterable {
    case replicate = "Replicate"
    case huggingface = "HuggingFace"
    case local = "Local"
}
