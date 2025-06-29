import Foundation
import Combine

/// Protocol for syncing data between devices
public protocol SyncProtocol {
    /// Sync status
    var syncStatus: CurrentValueSubject<SyncStatus, Never> { get }
    
    /// Start syncing
    func startSync() async throws
    
    /// Stop syncing
    func stopSync()
    
    /// Force sync now
    func syncNow() async throws
    
    /// Handle conflict resolution
    func resolveConflict(_ conflict: SyncConflict) async throws -> ConflictResolution
}

public enum SyncStatus {
    case idle
    case syncing
    case error(Error)
    case conflict(SyncConflict)
}

public struct SyncConflict {
    public let localVersion: Any
    public let remoteVersion: Any
    public let timestamp: Date
    public let identifier: String
}

public enum ConflictResolution {
    case useLocal
    case useRemote
    case merge(Any)
}