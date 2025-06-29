import Foundation
import Combine

@available(iOS 13.0, macOS 10.15, *)
public final class SimpleSyncManager: ObservableObject {
    public static let shared = SimpleSyncManager()
    
    @Published public var syncStatusText: String = "Unknown"
    @Published public var lastSyncDate: Date?
    @Published public var isSyncing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        #if canImport(CloudKit)
        // Subscribe to CloudKitManager updates
        CloudKitManager.shared.$syncStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncStatusText)
        
        CloudKitManager.shared.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastSyncDate)
        
        CloudKitManager.shared.$isSyncing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSyncing)
        #else
        syncStatusText = "CloudKit not available"
        #endif
    }
    
    public func checkSyncStatus() {
        #if canImport(CloudKit)
        CloudKitManager.shared.checkAccountStatus()
        #else
        syncStatusText = "CloudKit not available"
        #endif
    }
    
    public func syncNow() async throws {
        #if canImport(CloudKit)
        try await CloudKitManager.shared.syncAll()
        #else
        // Fallback to local storage only
        await MainActor.run {
            syncStatusText = "Local only"
            lastSyncDate = Date()
        }
        #endif
    }
}

// Simple storage manager for app group
public final class SimpleStorageManager {
    public static let shared = SimpleStorageManager()
    
    private let appGroupIdentifier = "group.projectmanager.shared"
    private let userDefaults: UserDefaults?
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // Generic save/load for Codable types
    public func save<T: Codable>(_ object: T, forKey key: String) {
        guard let userDefaults = userDefaults else { return }
        
        do {
            let data = try JSONEncoder().encode(object)
            userDefaults.set(data, forKey: key)
        } catch {
            print("Failed to save \(key): \(error)")
        }
    }
    
    public func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to load \(key): \(error)")
            return nil
        }
    }
}