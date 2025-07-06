
import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import Combine

/// Manages the syncing of `FocusedProject` data with CloudKit.
@available(iOS 13.0, macOS 10.15, *)
public final class FocusedProjectSyncManager {
    #if canImport(CloudKit)
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordType = "FocusedProject"
    
    public init() {
        self.container = CKContainer(identifier: "iCloud.AOTondra.ProjectManageriOS")
        self.privateDatabase = container.privateCloudDatabase
    }
    
    /// Cleans up duplicate records in CloudKit
    public func cleanupDuplicates() async throws {
        print("=== Cleaning up duplicate FocusedProject records ===")
        
        // Fetch all records using a simple query on syncType field
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "syncType == %@", "focused"))
        
        var allRecords: [(CKRecord.ID, CKRecord)] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }
            
            operation.resultsLimit = 100
            operation.qualityOfService = .userInitiated
            
            let (results, nextCursor) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([(CKRecord.ID, Result<CKRecord, Error>)], CKQueryOperation.Cursor?), Error>) in
                var fetchedRecords: [(CKRecord.ID, Result<CKRecord, Error>)] = []
                
                operation.recordMatchedBlock = { recordID, result in
                    fetchedRecords.append((recordID, result))
                }
                
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(let cursor):
                        continuation.resume(returning: (fetchedRecords, cursor))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                privateDatabase.add(operation)
            }
            
            // Process results
            for (recordID, result) in results {
                if case .success(let record) = result {
                    allRecords.append((recordID, record))
                }
            }
            
            cursor = nextCursor
        } while cursor != nil
        
        print("Fetched \(allRecords.count) total FocusedProject records")
        
        // Group by projectId
        var recordsByProjectId = [UUID: [(CKRecord.ID, CKRecord)]]()
        
        for (recordID, record) in allRecords {
            if let projectIdString = record["projectId"] as? String,
               let projectId = UUID(uuidString: projectIdString) {
                if recordsByProjectId[projectId] == nil {
                    recordsByProjectId[projectId] = []
                }
                recordsByProjectId[projectId]?.append((recordID, record))
            }
        }
        
        // Find and delete duplicates
        var recordsToDelete = [CKRecord.ID]()
        for (projectId, records) in recordsByProjectId {
            if records.count > 1 {
                print("Found \(records.count) records for project \(projectId)")
                
                // Keep the one with Active status, or the newest if all have same status
                let sorted = records.sorted { (a, b) in
                    // First priority: Active status
                    let statusA = a.1["status"] as? String ?? "Inactive"
                    let statusB = b.1["status"] as? String ?? "Inactive"
                    
                    if statusA == "Active" && statusB != "Active" {
                        return true
                    } else if statusA != "Active" && statusB == "Active" {
                        return false
                    }
                    
                    // Second priority: most recent modification date
                    let dateA = a.1.modificationDate ?? Date.distantPast
                    let dateB = b.1.modificationDate ?? Date.distantPast
                    return dateA > dateB
                }
                
                // Log which one we're keeping
                if let keepingRecord = sorted.first {
                    let status = keepingRecord.1["status"] as? String ?? "nil"
                    print("  Keeping record with status: \(status), modified: \(keepingRecord.1.modificationDate?.description ?? "unknown")")
                }
                
                // Delete all but the first (best)
                for i in 1..<sorted.count {
                    recordsToDelete.append(sorted[i].0)
                    let status = sorted[i].1["status"] as? String ?? "nil"
                    print("  Will delete duplicate record: \(sorted[i].0.recordName) (status: \(status))")
                }
            }
        }
        
        if !recordsToDelete.isEmpty {
            print("Deleting \(recordsToDelete.count) duplicate records...")
            let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsToDelete)
            deleteOp.qualityOfService = .userInitiated
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                deleteOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("Successfully deleted \(recordsToDelete.count) duplicate records")
                        continuation.resume()
                    case .failure(let error):
                        print("Failed to delete duplicates: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
                privateDatabase.add(deleteOp)
            }
        } else {
            print("No duplicate records found")
        }
    }
    
    /// Force updates specific FocusedProject records in CloudKit
    public func forceUpdate(_ projects: [FocusedProject]) async throws {
        guard !projects.isEmpty else { return }
        
        print("=== FocusedProjectSyncManager forceUpdate ===")
        print("Force updating \(projects.count) projects")
        
        // First clean up any duplicates
        try await cleanupDuplicates()
        
        // Wait a moment after cleanup
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Now proceed with delete and recreate
        let recordIDs = projects.map { CKRecord.ID(recordName: $0.projectId.uuidString) }
        
        // Delete ALL records with these project IDs (not just by record name)
        print("Finding and deleting ALL records for these project IDs...")
        let projectIds = projects.map { $0.projectId }
        var allRecordsToDelete = [CKRecord.ID]()
        
        // Query for each project ID to find ALL matching records
        for projectId in projectIds {
            let predicate = NSPredicate(format: "projectId == %@", projectId.uuidString)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            
            do {
                let results = try await privateDatabase.records(matching: query)
                for record in results.matchResults {
                    if case .success(let recordResult) = record.1 {
                        allRecordsToDelete.append(recordResult.recordID)
                        print("  Found record to delete: \(recordResult.recordID.recordName)")
                    }
                }
            } catch {
                print("Error querying for project \(projectId): \(error)")
            }
        }
        
        if !allRecordsToDelete.isEmpty {
            print("Deleting \(allRecordsToDelete.count) records...")
            do {
                let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: allRecordsToDelete)
                deleteOp.qualityOfService = .userInitiated
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    deleteOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("Successfully deleted \(allRecordsToDelete.count) records")
                            continuation.resume()
                        case .failure(let error):
                            print("Delete operation failed: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    privateDatabase.add(deleteOp)
                }
            } catch {
                print("Delete phase completed with error: \(error)")
            }
        }
        
        // Wait a moment after deletion
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Now create fresh records
        let recordsToSave = projects.map { project in
            let record = recordFromFocusedProject(project, existingRecord: nil) // Always create new
            print("Creating new record for \(project.projectId): status=\(project.status.rawValue)")
            return record
        }
        
        // Save new records
        let saveOp = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        saveOp.savePolicy = .allKeys
        saveOp.qualityOfService = .userInitiated
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            saveOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("Successfully created \(recordsToSave.count) new records")
                    // Update local storage immediately with the forced data
                    SimpleStorageManager.shared.save(projects, forKey: "shared_focusedProjects")
                    continuation.resume()
                case .failure(let error):
                    print("Failed to create new records: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(saveOp)
        }
    }
    
    /// Fetches specific FocusedProject records by IDs
    public func fetchByIds(_ projectIds: [UUID]) async throws -> [FocusedProject] {
        guard !projectIds.isEmpty else { return [] }
        
        print("Fetching \(projectIds.count) specific records from CloudKit")
        let recordIDs = projectIds.map { CKRecord.ID(recordName: $0.uuidString) }
        
        do {
            let fetchedRecords = try await privateDatabase.records(for: recordIDs)
            print("Received \(fetchedRecords.count) results from CloudKit")
            
            var projects: [FocusedProject] = []
            for (recordID, result) in fetchedRecords {
                switch result {
                case .success(let record):
                    print("Successfully fetched record \(recordID.recordName)")
                    print("  Record type: \(record.recordType)")
                    print("  Fields: \(record.allKeys())")
                    if let project = focusedProjectFromRecord(record) {
                        projects.append(project)
                        print("  Parsed as: \(project.projectId) with status \(project.status.rawValue)")
                    } else {
                        print("  Failed to parse record")
                    }
                case .failure(let error):
                    print("Failed to fetch record \(recordID.recordName): \(error)")
                }
            }
            
            return projects
        } catch {
            print("Error in fetchByIds: \(error)")
            throw error
        }
    }
    
    /// Fetches all `FocusedProject` records from CloudKit.
    public func fetchAll() async throws -> [FocusedProject] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "syncType == %@", "focused"))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        
        do {
            repeat {
                let operation: CKQueryOperation
                if let cursor = cursor {
                    operation = CKQueryOperation(cursor: cursor)
                } else {
                    operation = CKQueryOperation(query: query)
                }
                
                operation.resultsLimit = 100
                operation.qualityOfService = .userInitiated
                
                let (results, nextCursor) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([(CKRecord.ID, Result<CKRecord, Error>)], CKQueryOperation.Cursor?), Error>) in
                    var fetchedRecords: [(CKRecord.ID, Result<CKRecord, Error>)] = []
                    
                    operation.recordMatchedBlock = { recordID, result in
                        fetchedRecords.append((recordID, result))
                    }
                    
                    operation.queryResultBlock = { result in
                        switch result {
                        case .success(let cursor):
                            continuation.resume(returning: (fetchedRecords, cursor))
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    
                    privateDatabase.add(operation)
                }
                
                // Process results
                for (_, result) in results {
                    if case .success(let record) = result {
                        allRecords.append(record)
                    }
                }
                
                cursor = nextCursor
            } while cursor != nil
            
            // Convert records to FocusedProject objects
            var focusedProjects: [FocusedProject] = []
            for record in allRecords {
                if let project = focusedProjectFromRecord(record) {
                    focusedProjects.append(project)
                }
            }
            
            print("Fetched \(focusedProjects.count) focused projects from CloudKit")
            return focusedProjects
        } catch {
            print("Failed to fetch focused projects: \(error)")
            throw error
        }
    }
    
    /// Syncs local `FocusedProject` data with CloudKit.
    public func sync(localProjects: [FocusedProject]) async throws {
        let cloudProjects = try await fetchAll()
        
        var mergedProjectDict = [UUID: FocusedProject]()
        var existingRecords = [UUID: CKRecord]()
        
        print("Syncing FocusedProjects - Local: \(localProjects.count), Cloud: \(cloudProjects.count)")
        
        // Fetch existing records to update them rather than create new ones
        let recordIDs = localProjects.map { CKRecord.ID(recordName: $0.projectId.uuidString) }
        if !recordIDs.isEmpty {
            do {
                let fetchedRecords = try await privateDatabase.records(for: recordIDs)
                for (recordID, result) in fetchedRecords {
                    if case .success(let record) = result {
                        if let projectIdString = record["projectId"] as? String,
                           let projectId = UUID(uuidString: projectIdString) {
                            existingRecords[projectId] = record
                            print("Found existing CloudKit record for project \(projectId)")
                        }
                    }
                }
            } catch {
                print("Error fetching existing records: \(error)")
            }
        }
        
        // First, add all cloud projects
        for project in cloudProjects {
            mergedProjectDict[project.projectId] = project
        }
        
        // Then merge with local projects using smart conflict resolution
        for localProject in localProjects {
            if let cloudProject = mergedProjectDict[localProject.projectId] {
                // Conflict: project exists in both local and cloud
                // Use the one with the most recent modification
                let useLocal = shouldUseLocalVersion(local: localProject, cloud: cloudProject)
                if useLocal {
                    mergedProjectDict[localProject.projectId] = localProject
                    print("Conflict resolved for \(localProject.projectId): using local version (status: \(localProject.status.rawValue))")
                } else {
                    print("Conflict resolved for \(localProject.projectId): keeping cloud version (status: \(cloudProject.status.rawValue))")
                }
            } else {
                // No conflict: project only exists locally
                mergedProjectDict[localProject.projectId] = localProject
                print("Adding local-only project \(localProject.projectId) (status: \(localProject.status.rawValue))")
            }
        }
        
        let mergedProjects = Array(mergedProjectDict.values)
        let recordsToSave = mergedProjects.map { project in
            recordFromFocusedProject(project, existingRecord: existingRecords[project.projectId])
        }
        
        if !recordsToSave.isEmpty {
            let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            modifyOp.savePolicy = .changedKeys // Only update changed fields
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                modifyOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("Successfully synced \(recordsToSave.count) focused projects")
                        continuation.resume()
                    case .failure(let error):
                        print("Failed to sync focused projects: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
                privateDatabase.add(modifyOp)
            }
        }
        
        // Save final merged data locally
        SimpleStorageManager.shared.save(mergedProjects, forKey: "shared_focusedProjects")
    }
    
    // MARK: - Conflict Resolution
    
    private func shouldUseLocalVersion(local: FocusedProject, cloud: FocusedProject) -> Bool {
        // Always prefer active status over inactive
        if local.status == .active && cloud.status == .inactive {
            print("Preferring local (Active) over cloud (Inactive) for project \(local.projectId)")
            return true
        } else if local.status == .inactive && cloud.status == .active {
            print("Preferring cloud (Active) over local (Inactive) for project \(local.projectId)")
            return false
        }
        
        // If both have the same status, use the one with more recent activity
        let localDate = local.lastWorkedOn ?? local.activatedDate ?? Date.distantPast
        let cloudDate = cloud.lastWorkedOn ?? cloud.activatedDate ?? Date.distantPast
        
        // Special case: if cloud has no dates at all, prefer local
        if cloudDate == Date.distantPast && localDate != Date.distantPast {
            print("Preferring local due to cloud having no date information for project \(local.projectId)")
            return true
        }
        
        let useLocal = localDate > cloudDate
        print("Date comparison for \(local.projectId): local=\(localDate) vs cloud=\(cloudDate), using \(useLocal ? "local" : "cloud")")
        return useLocal
    }
    
    // MARK: - Record Conversions
    
    private func recordFromFocusedProject(_ focusedProject: FocusedProject, existingRecord: CKRecord? = nil) -> CKRecord {
        let recordID = CKRecord.ID(recordName: focusedProject.projectId.uuidString)
        let record = existingRecord ?? CKRecord(recordType: recordType, recordID: recordID)
        
        // Ensure critical fields are always set
        record["projectId"] = focusedProject.projectId.uuidString as CKRecordValue
        record["syncType"] = "focused" as CKRecordValue
        
        // CRITICAL: Ensure status is always set and valid
        let statusValue = focusedProject.status.rawValue
        record["status"] = statusValue as CKRecordValue
        
        // Verify the status was actually set
        if record["status"] == nil {
            print("⚠️ CRITICAL: Failed to set status field for project \(focusedProject.projectId)!")
        } else {
            print("✅ Status field set to '\(statusValue)' for project \(focusedProject.projectId)")
        }
        
        // Set optional date fields
        if let lastWorkedOn = focusedProject.lastWorkedOn {
            record["lastWorkedOn"] = lastWorkedOn as CKRecordValue
        }
        if let activatedDate = focusedProject.activatedDate {
            record["activatedDate"] = activatedDate as CKRecordValue
        }
        
        // Log complete record details
        print("Preparing FocusedProject record for CloudKit:")
        print("  - ID: \(focusedProject.projectId)")
        print("  - Status: \(focusedProject.status.rawValue) (verified: \(record["status"] != nil))")
        print("  - LastWorked: \(focusedProject.lastWorkedOn?.description ?? "nil")")
        print("  - Activated: \(focusedProject.activatedDate?.description ?? "nil")")
        
        return record
    }
    
    private func focusedProjectFromRecord(_ record: CKRecord) -> FocusedProject? {
        guard let projectIdString = record["projectId"] as? String,
              let projectId = UUID(uuidString: projectIdString) else {
            print("Failed to parse FocusedProject record: Missing or invalid projectId.")
            return nil
        }
        
        // Handle status field that might be nil/empty in CloudKit
        let status: ProjectStatus
        if let statusString = record["status"] as? String,
           let parsedStatus = ProjectStatus(rawValue: statusString) {
            status = parsedStatus
            print("Parsed status from CloudKit: '\(statusString)' -> \(status.rawValue)")
        } else {
            // If status is nil/empty, try to infer from dates
            let lastWorkedOn = record["lastWorkedOn"] as? Date
            let activatedDate = record["activatedDate"] as? Date
            
            // If it has an activated date, it was likely active
            if activatedDate != nil {
                status = .active
                print("⚠️ Status was nil/empty in CloudKit! Inferring as Active based on activatedDate")
            } else {
                status = .inactive
                print("⚠️ Status was nil/empty in CloudKit! Defaulting to Inactive")
            }
        }
        
        var focusedProject = FocusedProject(projectId: projectId, status: status)
        
        if let lastWorkedOn = record["lastWorkedOn"] as? Date {
            focusedProject.lastWorkedOn = lastWorkedOn
        }
        if let activatedDate = record["activatedDate"] as? Date {
            focusedProject.activatedDate = activatedDate
        }
        
        print("Parsed FocusedProject from CloudKit: ID=\(focusedProject.projectId), Status=\(focusedProject.status.rawValue), LastWorked=\(focusedProject.lastWorkedOn?.description ?? "nil"), Activated=\(focusedProject.activatedDate?.description ?? "nil")")
        
        return focusedProject
    }
    #endif
}
