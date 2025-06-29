import Foundation
import CryptoKit

class SecureTokenStorage {
    static let shared = SecureTokenStorage()
    
    private init() {}
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("ProjectManager", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        return appDirectory.appendingPathComponent("tokens.encrypted")
    }
    
    private var keyURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("ProjectManager", isDirectory: true)
        return appDirectory.appendingPathComponent("key.data")
    }
    
    // Generate or retrieve encryption key
    private func getOrCreateKey() -> SymmetricKey {
        if let keyData = try? Data(contentsOf: keyURL) {
            return SymmetricKey(data: keyData)
        } else {
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            try? keyData.write(to: keyURL)
            return key
        }
    }
    
    // Token storage dictionary
    private func loadTokens() -> [String: String] {
        guard let encryptedData = try? Data(contentsOf: storageURL) else {
            return [:]
        }
        
        let key = getOrCreateKey()
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            let tokens = try JSONDecoder().decode([String: String].self, from: decryptedData)
            return tokens
        } catch {
            print("SecureTokenStorage: Failed to decrypt tokens: \(error)")
            return [:]
        }
    }
    
    private func saveTokens(_ tokens: [String: String]) {
        let key = getOrCreateKey()
        
        do {
            let data = try JSONEncoder().encode(tokens)
            let encryptedData = try AES.GCM.seal(data, using: key)
            try encryptedData.combined?.write(to: storageURL)
            print("SecureTokenStorage: Successfully saved \(tokens.count) tokens")
        } catch {
            print("SecureTokenStorage: Failed to encrypt and save tokens: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func saveToken(_ token: String, for key: String) {
        var tokens = loadTokens()
        tokens[key] = token
        saveTokens(tokens)
    }
    
    func getToken(for key: String) -> String? {
        let tokens = loadTokens()
        return tokens[key]
    }
    
    func deleteToken(for key: String) {
        var tokens = loadTokens()
        tokens.removeValue(forKey: key)
        saveTokens(tokens)
    }
    
    func hasToken(for key: String) -> Bool {
        let tokens = loadTokens()
        return tokens[key] != nil
    }
    
    // MARK: - GitHub Methods
    
    func saveGitHubToken(_ token: String) {
        saveToken(token, for: "github-access-token")
    }
    
    func getGitHubToken() -> String? {
        return getToken(for: "github-access-token")
    }
    
    func deleteGitHubToken() {
        deleteToken(for: "github-access-token")
    }
    
    func hasGitHubToken() -> Bool {
        return hasToken(for: "github-access-token")
    }
    
    // MARK: - OpenAI Methods
    
    func saveOpenAIKey(_ key: String) {
        saveToken(key, for: "openai-api-key")
    }
    
    func getOpenAIKey() -> String? {
        return getToken(for: "openai-api-key")
    }
    
    func deleteOpenAIKey() {
        deleteToken(for: "openai-api-key")
    }
    
    func hasOpenAIKey() -> Bool {
        return hasToken(for: "openai-api-key")
    }
}