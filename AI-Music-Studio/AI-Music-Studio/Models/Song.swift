import Foundation

struct Song: Identifiable, Codable {
    let id: UUID
    var title: String
    var prompt: String
    var duration: Double
    var filePath: URL?
    var createdAt: Date
    var genre: String?
    var mood: String?
    var bpm: Int?
    
    init(
        id: UUID = UUID(),
        title: String,
        prompt: String,
        duration: Double = 0,
        filePath: URL? = nil,
        createdAt: Date = Date(),
        genre: String? = nil,
        mood: String? = nil,
        bpm: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.duration = duration
        self.filePath = filePath
        self.createdAt = createdAt
        self.genre = genre
        self.mood = mood
        self.bpm = bpm
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
