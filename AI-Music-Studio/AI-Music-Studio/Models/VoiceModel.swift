import Foundation

struct VoiceModel: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var sampleFilePath: URL?
    var modelFilePath: URL?
    var createdAt: Date
    var isTrained: Bool
    var trainingProgress: Double
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        sampleFilePath: URL? = nil,
        modelFilePath: URL? = nil,
        createdAt: Date = Date(),
        isTrained: Bool = false,
        trainingProgress: Double = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sampleFilePath = sampleFilePath
        self.modelFilePath = modelFilePath
        self.createdAt = createdAt
        self.isTrained = isTrained
        self.trainingProgress = trainingProgress
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
}
