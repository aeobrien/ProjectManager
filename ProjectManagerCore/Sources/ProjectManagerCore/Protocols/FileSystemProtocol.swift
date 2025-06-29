import Foundation

/// Protocol for file system operations to abstract platform-specific implementations
public protocol FileSystemProtocol {
    /// Read file contents as string
    func readFile(at url: URL) throws -> String
    
    /// Write string contents to file
    func writeFile(contents: String, to url: URL) throws
    
    /// Check if file exists
    func fileExists(at url: URL) -> Bool
    
    /// Create directory
    func createDirectory(at url: URL) throws
    
    /// List contents of directory
    func contentsOfDirectory(at url: URL) throws -> [URL]
    
    /// Delete item
    func removeItem(at url: URL) throws
    
    /// Move item
    func moveItem(from sourceURL: URL, to destinationURL: URL) throws
    
    /// Copy item
    func copyItem(from sourceURL: URL, to destinationURL: URL) throws
}

/// Default implementation using FileManager for macOS/iOS
public struct LocalFileSystem: FileSystemProtocol {
    public init() {}
    
    public func readFile(at url: URL) throws -> String {
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    public func writeFile(contents: String, to url: URL) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
    
    public func fileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    public func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }
    
    public func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    public func moveItem(from sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }
    
    public func copyItem(from sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }
}