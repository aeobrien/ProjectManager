// Re-export all public types from the module
@_exported import Foundation
@_exported import Combine

// Explicitly reference the types to ensure they're included in the module
@available(iOS 13.0, macOS 10.15, *)
public typealias PMSimpleSyncManager = SimpleSyncManager

#if canImport(CloudKit)
import CloudKit
@available(iOS 13.0, macOS 10.15, *)
public typealias PMCloudKitManager = CloudKitManager
#endif

public typealias PMSimpleStorageManager = SimpleStorageManager

// This file ensures all public types are properly exported