import SwiftUI

struct MusicLibraryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var songs: [Song] = []
    @State private var selectedSong: Song?
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .date
    #if os(iOS)
    @State private var shareItem: ShareableFile?
    #endif
    
    enum SortOrder: String, CaseIterable {
        case date = "日期"
        case name = "名称"
        case duration = "时长"
    }
    
    var filteredSongs: [Song] {
        let result = songs.filter { song in
            if searchText.isEmpty {
                return true
            }
            return song.title.localizedCaseInsensitiveContains(searchText) ||
                   song.prompt.localizedCaseInsensitiveContains(searchText)
        }
        
        switch sortOrder {
        case .date:
            return result.sorted { $0.createdAt > $1.createdAt }
        case .name:
            return result.sorted { $0.title < $1.title }
        case .duration:
            return result.sorted { $0.duration > $1.duration }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            #if os(iOS)
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索音乐...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.appControlBackground)
                .cornerRadius(8)
                
                HStack(spacing: 12) {
                    Picker("", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    
                    Button(action: { loadSongs() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            #else
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索音乐...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.appControlBackground)
                .cornerRadius(8)
                
                Picker("", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 80)
                
                Button(action: { loadSongs() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            #endif
            
            Divider()
            
            if songs.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .background(Color.appTextBackground)
        #if os(iOS)
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url) { shareItem = nil }
        }
        #endif
        .onAppear {
            loadSongs()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                Text("音乐库")
                    .font(.system(size: 28, weight: .bold))
            }
            
            Text("管理你生成的所有音乐")
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
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无音乐")
                .font(.system(size: 18, weight: .medium))
            
            Text("在「AI写歌」中生成你的第一首音乐")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var gridColumns: [GridItem] {
        #if os(iOS)
        return [GridItem(.flexible()), GridItem(.flexible())]
        #else
        return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        #endif
    }
    
    private var listView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(filteredSongs) { song in
                    SongCardView(
                        song: song,
                        isSelected: selectedSong?.id == song.id,
                        audioPlayer: audioPlayer
                    ) {
                        selectedSong = song
                    } onDelete: {
                        deleteSong(song)
                    } onExport: {
                        exportSong(song)
                    }
                }
            }
            .padding()
        }
    }
    
    private func loadSongs() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let songsPath = documentsPath.appendingPathComponent("Songs", isDirectory: true)
        
        var loadedSongs: [Song] = []
        
        guard FileManager.default.fileExists(atPath: songsPath.path) else {
            songs = []
            return
        }
        
        let metadataPath = songsPath.appendingPathComponent("metadata.json")
        
        if let data = try? Data(contentsOf: metadataPath),
           let savedSongs = try? JSONDecoder().decode([Song].self, from: data) {
            loadedSongs = savedSongs.filter { song in
                guard let filePath = song.filePath else { return false }
                return FileManager.default.fileExists(atPath: filePath.path)
            }
        }
        
        songs = loadedSongs
    }
    
    private func deleteSong(_ song: Song) {
        if let filePath = song.filePath {
            try? FileManager.default.removeItem(at: filePath)
        }
        
        songs.removeAll { $0.id == song.id }
        saveMetadata()
    }
    
    private func saveMetadata() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let songsPath = documentsPath.appendingPathComponent("Songs", isDirectory: true)
        let metadataPath = songsPath.appendingPathComponent("metadata.json")
        
        if let data = try? JSONEncoder().encode(songs) {
            try? data.write(to: metadataPath)
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

struct SongCardView: View {
    let song: Song
    let isSelected: Bool
    let audioPlayer: AudioPlayer
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行 - 点击选中卡片
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    
                    if let genre = song.genre {
                        Text(genre)
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Menu 按钮 - 独立点击区域
                Menu {
                    Button(action: onExport) {
                        Label("导出MP3", systemImage: "square.and.arrow.down")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                }
                .menuStyle(.borderlessButton)
                #if os(iOS)
                .opacity(1)
                #else
                .opacity(isHovered ? 1 : 0)
                #endif
            }
            
            // 描述文本
            Text(song.prompt)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // 信息行
            HStack {
                Label(song.formattedDuration, systemImage: "clock")
                
                Spacer()
                
                Label(song.formattedDate, systemImage: "calendar")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            
            // 音频播放器 - 独立交互区域
            if let audioURL = song.filePath {
                AudioPlayerView(audioPlayer: audioPlayer, audioURL: audioURL, compact: true)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.appControlBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    MusicLibraryView()
        .environmentObject(AppState())
}
