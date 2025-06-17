import Foundation

struct Project: Identifiable, Hashable {
    let id: UUID
    let name: String
    let folderPath: URL
    var overviewPath: URL {
        folderPath.appendingPathComponent("\(name).md")
    }
    var hasOverview: Bool {
        FileManager.default.fileExists(atPath: overviewPath.path)
    }
    
    init(folderPath: URL) {
        self.folderPath = folderPath
        self.name = folderPath.lastPathComponent
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