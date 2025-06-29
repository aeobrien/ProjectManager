import Foundation

public struct Project: Identifiable, Hashable, Codable {
    public let id: UUID
    public let name: String
    public let folderPath: URL
    public var overviewContent: String? // For iOS to store synced content
    
    public var overviewPath: URL {
        folderPath.appendingPathComponent("\(name).md")
    }
    public var hasOverview: Bool {
        if overviewContent != nil {
            return true // iOS uses synced content
        }
        return FileManager.default.fileExists(atPath: overviewPath.path)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case folderPath
        case overviewContent
    }
    
    public init(folderPath: URL, overviewContent: String? = nil) {
        self.folderPath = folderPath
        self.name = folderPath.lastPathComponent
        self.overviewContent = overviewContent
        // Generate stable UUID based on folder path
        self.id = UUID(uuidString: Self.generateStableUUID(from: folderPath.absoluteString)) ?? UUID()
    }
    
    private static func generateStableUUID(from string: String) -> String {
        // Create a deterministic UUID based on the folder path using simple hash
        let hash = string.utf8.reduce(into: UInt64(0)) { result, byte in
            result = result &* 31 &+ UInt64(byte)
        }
        
        // Split the hash into 4 parts for UUID format
        let part1 = UInt32(hash & 0xFFFFFFFF)
        let part2 = UInt16((hash >> 32) & 0xFFFF)
        let part3 = UInt16((hash >> 48) & 0xFFFF)
        let part4 = UInt16(hash.byteSwapped & 0xFFFF)
        let part5 = UInt64(hash.byteSwapped >> 16) & 0xFFFFFFFFFFFF
        
        // Format as UUID string with correct bit sizes
        let uuidString = String(format: "%08X-%04X-%04X-%04X-%012llX",
                               part1, part2, part3, part4, part5)
        
        return uuidString
    }
}