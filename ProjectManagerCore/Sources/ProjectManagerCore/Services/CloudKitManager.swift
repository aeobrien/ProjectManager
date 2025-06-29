import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import Combine


#if canImport(CloudKit)
@available(iOS 13.0, macOS 10.15, *)
public final class CloudKitManager: ObservableObject {
    public static let shared = CloudKitManager()
    
    @Published public var syncStatus: String = "Unknown"
    @Published public var lastSyncDate: Date?
    @Published public var isSyncing: Bool = false
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    private var schemaInitialized = false
    
    // Record type names
    private let projectRecordType = "Project"
    private let focusTaskRecordType = "FocusTask"
    private let focusedProjectRecordType = "FocusedProject"
    
    private init() {
        self.container = CKContainer(identifier: "iCloud.AOTondra.ProjectManageriOS")
        self.privateDatabase = container.privateCloudDatabase
        
        // Reset schema flag when initializing
        schemaInitialized = false
        
        checkAccountStatus()
    }
    
    // MARK: - Account Status
    
    public func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.syncStatus = "Error: \(error.localizedDescription)"
                    return
                }
                
                switch status {
                case .available:
                    self.syncStatus = "Ready"
                    Task {
                        // Initialize schema when account is available
                        await self.initializeSchema()
                        self.setupSubscriptions()
                    }
                case .noAccount:
                    self.syncStatus = "Not Signed In"
                case .restricted:
                    self.syncStatus = "Restricted"
                case .couldNotDetermine:
                    self.syncStatus = "Unknown"
                case .temporarilyUnavailable:
                    self.syncStatus = "Temporarily Unavailable"
                @unknown default:
                    self.syncStatus = "Unknown"
                }
            }
        }
    }
    
    // MARK: - Setup
    
    private func initializeSchema() async {
        // This will create the record types in development environment
        // In production, you need to deploy the schema from CloudKit Dashboard
        
        print("Checking CloudKit schema for container: \(container.containerIdentifier ?? "unknown")")
        
        // First check if schema already exists by trying a simple query
        let testQuery = CKQuery(recordType: projectRecordType, predicate: NSPredicate(format: "syncType == %@", "project"))
        do {
            let _ = try await privateDatabase.records(matching: testQuery)
            print("Schema already exists, skipping initialization")
            schemaInitialized = true
            return
        } catch {
            print("Schema doesn't exist yet, will initialize: \(error)")
        }
        
        // Create a dummy record for each type to initialize the schema
        let projectRecord = CKRecord(recordType: projectRecordType)
        projectRecord["id"] = UUID().uuidString as CKRecordValue
        projectRecord["name"] = "Schema Init" as CKRecordValue
        projectRecord["folderPath"] = "file:///tmp" as CKRecordValue
        projectRecord["syncType"] = "project" as CKRecordValue  // Add a queryable field
        projectRecord["overviewContent"] = "# Schema Init\n\nThis is a test record." as CKRecordValue
        
        let focusTaskRecord = CKRecord(recordType: focusTaskRecordType)
        focusTaskRecord["id"] = UUID().uuidString as CKRecordValue
        focusTaskRecord["text"] = "Schema Init" as CKRecordValue
        focusTaskRecord["status"] = "none" as CKRecordValue
        focusTaskRecord["projectId"] = UUID().uuidString as CKRecordValue
        focusTaskRecord["lastModified"] = Date() as CKRecordValue
        focusTaskRecord["syncType"] = "task" as CKRecordValue  // Add a queryable field
        
        let focusedProjectRecord = CKRecord(recordType: focusedProjectRecordType)
        focusedProjectRecord["id"] = UUID().uuidString as CKRecordValue
        focusedProjectRecord["projectId"] = UUID().uuidString as CKRecordValue
        focusedProjectRecord["status"] = "Inactive" as CKRecordValue
        focusedProjectRecord["syncType"] = "focused" as CKRecordValue  // Add a queryable field
        
        // Try to save and then delete to create schema
        do {
            print("Creating Project record type...")
            let savedProject = try await privateDatabase.save(projectRecord)
            print("Project record type created successfully")
            // Delete the initialization record
            try await privateDatabase.deleteRecord(withID: savedProject.recordID)
            print("Deleted initialization record")
        } catch {
            print("Project schema init error: \(error)")
        }
        
        do {
            print("Creating FocusTask record type...")
            let savedTask = try await privateDatabase.save(focusTaskRecord)
            print("FocusTask record type created successfully")
            // Delete the initialization record
            try await privateDatabase.deleteRecord(withID: savedTask.recordID)
        } catch {
            print("FocusTask schema init error: \(error)")
        }
        
        do {
            print("Creating FocusedProject record type...")
            let savedFocused = try await privateDatabase.save(focusedProjectRecord)
            print("FocusedProject record type created successfully")
            // Delete the initialization record
            try await privateDatabase.deleteRecord(withID: savedFocused.recordID)
        } catch {
            print("FocusedProject schema init error: \(error)")
        }
        
        print("CloudKit schema initialization completed")
        schemaInitialized = true
    }
    
    private func setupSubscriptions() {
        // Set up push notifications for changes
        let subscription = CKDatabaseSubscription(subscriptionID: "project-changes")
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { _, error in
            if let error = error {
                print("Failed to create subscription: \(error)")
            }
        }
    }
    
    // MARK: - Sync Managers
    
    private let projectSyncManager = ProjectSyncManager()
    private let focusedProjectSyncManager = FocusedProjectSyncManager()
    private let focusTaskSyncManager = FocusTaskSyncManager()
    
    // MARK: - Sync Operations
    
    public func syncAll() async throws {
        if !schemaInitialized {
            print("Waiting for schema initialization...")
            await initializeSchema()
        }
        
        await MainActor.run {
            isSyncing = true
            syncStatus = "Syncing..."
        }
        
        do {
            // Sync projects
            let localProjects = SimpleStorageManager.shared.load([Project].self, forKey: "shared_projects") ?? []
            try await projectSyncManager.sync(localProjects: localProjects)
            
            // Sync focused projects
            let localFocusedProjects = SimpleStorageManager.shared.load([FocusedProject].self, forKey: "shared_focusedProjects") ?? []
            try await focusedProjectSyncManager.sync(localProjects: localFocusedProjects)
            
            // Sync focus tasks
            let localTasks = SimpleStorageManager.shared.load([FocusTask].self, forKey: "shared_focusTasks") ?? []
            try await focusTaskSyncManager.sync(localTasks: localTasks)
            
            await MainActor.run {
                lastSyncDate = Date()
                syncStatus = "Synced"
                isSyncing = false
            }
            
            SimpleStorageManager.shared.save(Date(), forKey: "lastCloudKitSync")
            NotificationCenter.default.post(name: Notification.Name("CloudKitSyncCompleted"), object: nil)
            
        } catch {
            await MainActor.run {
                syncStatus = "Error: \(error.localizedDescription)"
                isSyncing = false
            }
            throw error
        }
    }
}
#endif
