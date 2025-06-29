import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // Use bundle identifier as service name for better sandboxing support
    private var serviceName: String {
        // Use the actual bundle identifier we see in the build output
        return "AOTondra.ProjectManager"
    }
    private let githubAccountName = "github-access-token"
    private let openAIAccountName = "openai-api-key"
    
    // MARK: - Generic Token Methods
    
    private func saveToken(_ token: String, accountName: String) -> Bool {
        let data = token.data(using: .utf8)!
        
        // First, delete any existing token
        _ = deleteToken(accountName: accountName)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("KeychainManager: Failed to save token for \(accountName). Status: \(status)")
            if let error = SecCopyErrorMessageString(status, nil) {
                print("KeychainManager: Error: \(error)")
            }
        } else {
            print("KeychainManager: Successfully saved token for \(accountName)")
        }
        
        return status == errSecSuccess
    }
    
    private func getToken(accountName: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data,
               let token = String(data: data, encoding: .utf8) {
                print("KeychainManager: Successfully retrieved token for \(accountName)")
                return token
            }
        } else if status == errSecItemNotFound {
            print("KeychainManager: No token found for \(accountName)")
        } else {
            print("KeychainManager: Failed to retrieve token for \(accountName). Status: \(status)")
            if let error = SecCopyErrorMessageString(status, nil) {
                print("KeychainManager: Error: \(error)")
            }
        }
        
        return nil
    }
    
    private func deleteToken(accountName: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - GitHub Token Methods
    
    func saveGitHubToken(_ token: String) -> Bool {
        return saveToken(token, accountName: githubAccountName)
    }
    
    func getGitHubToken() -> String? {
        return getToken(accountName: githubAccountName)
    }
    
    func deleteGitHubToken() -> Bool {
        return deleteToken(accountName: githubAccountName)
    }
    
    func hasGitHubToken() -> Bool {
        return getGitHubToken() != nil
    }
    
    // MARK: - OpenAI Token Methods
    
    func saveOpenAIKey(_ key: String) -> Bool {
        return saveToken(key, accountName: openAIAccountName)
    }
    
    func getOpenAIKey() -> String? {
        return getToken(accountName: openAIAccountName)
    }
    
    func deleteOpenAIKey() -> Bool {
        return deleteToken(accountName: openAIAccountName)
    }
    
    func hasOpenAIKey() -> Bool {
        return getOpenAIKey() != nil
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    func saveToken(_ token: String) -> Bool {
        return saveGitHubToken(token)
    }
    
    func getToken() -> String? {
        return getGitHubToken()
    }
    
    func deleteToken() -> Bool {
        return deleteGitHubToken()
    }
    
    func hasToken() -> Bool {
        return hasGitHubToken()
    }
    
    // MARK: - Debug Methods
    
    func testKeychain() {
        print("\n=== Keychain Test ===")
        print("Service Name: \(serviceName)")
        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
        
        // Test GitHub token
        let testGitHubToken = "test-github-token-123"
        print("\nTesting GitHub token...")
        if saveGitHubToken(testGitHubToken) {
            print("✅ Saved test GitHub token")
            if let retrieved = getGitHubToken() {
                print("✅ Retrieved GitHub token: \(retrieved)")
                print("✅ Tokens match: \(retrieved == testGitHubToken)")
            } else {
                print("❌ Failed to retrieve GitHub token")
            }
            
            if deleteGitHubToken() {
                print("✅ Deleted test GitHub token")
            }
        } else {
            print("❌ Failed to save test GitHub token")
        }
        
        // Test OpenAI key
        let testOpenAIKey = "test-openai-key-456"
        print("\nTesting OpenAI key...")
        if saveOpenAIKey(testOpenAIKey) {
            print("✅ Saved test OpenAI key")
            if let retrieved = getOpenAIKey() {
                print("✅ Retrieved OpenAI key: \(retrieved)")
                print("✅ Keys match: \(retrieved == testOpenAIKey)")
            } else {
                print("❌ Failed to retrieve OpenAI key")
            }
            
            if deleteOpenAIKey() {
                print("✅ Deleted test OpenAI key")
            }
        } else {
            print("❌ Failed to save test OpenAI key")
        }
        
        print("\n=== End Keychain Test ===\n")
    }
}